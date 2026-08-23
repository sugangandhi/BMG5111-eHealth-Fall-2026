"""
Field mapper using Claude Haiku via Anthropic API.
Given a form schema and a patient context, fills each field
with a value, confidence level, and source citation.
"""
import json
import os
from openai import OpenAI
from dataclasses import dataclass

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

CONFIDENCE_HIGH = "HIGH"
CONFIDENCE_MEDIUM = "MEDIUM"
CONFIDENCE_LOW = "LOW"
CONFIDENCE_MISSING = "MISSING"


@dataclass
class FilledField:
    key: str
    label: str
    value: str
    confidence: str     # HIGH | MEDIUM | LOW | MISSING
    source: str         # e.g. "Patient.birthDate", "Condition onset date"
    note: str           # explanation or caveat for the doctor


MAPPING_PROMPT = """You are a medical office assistant helping fill out a form for a Canadian primary care physician.

PATIENT RECORD:
{patient_context}

FORM TO COMPLETE:
Form name: {form_type}
Purpose: {purpose}

FIELDS TO FILL:
{fields_json}

For each field, provide:
- key: the field key (same as provided)
- value: the best value from the patient record (empty string if unknown)
- confidence: HIGH (directly from record), MEDIUM (inferred/calculated), LOW (best guess, uncertain), or MISSING (cannot determine)
- source: where in the patient record you found this (e.g. "Patient demographics", "Work-related injury condition", "Encounter notes from 2026-05-28")
- note: brief explanation or caveat for the physician (e.g. "Please verify exact injury time", or "Pulled from most recent encounter")

Rules:
- Use ONLY information present in the patient record above
- Do NOT invent or hallucinate values
- For dates, use YYYY-MM-DD format
- For missing clinical judgements (prognosis, return-to-work timeline), mark MISSING and explain what the physician needs to add
- Mark signature fields as MISSING always
- If a field requires physician licence/CPSO number, use the physician data from the record

Return ONLY a JSON array of filled fields:
[
  {{
    "key": "...",
    "value": "...",
    "confidence": "...",
    "source": "...",
    "note": "..."
  }}
]
"""


def map_fields(
    form_type: str,
    purpose: str,
    fields: list[dict],
    patient_context: str,
) -> list[FilledField]:
    """
    Calls local Gemma2 to map patient data onto form fields.
    Returns a list of FilledField with confidence scores.
    """
    fields_json = json.dumps(
        [{"key": f["key"], "label": f["label"], "what_it_needs": f["what_it_needs"], "fhir_hint": f["fhir_hint"]} for f in fields],
        indent=2,
    )

    prompt = MAPPING_PROMPT.format(
        patient_context=patient_context,
        form_type=form_type,
        purpose=purpose,
        fields_json=fields_json,
    )

    response = _client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "user", "content": prompt}],
    )

    generated = response.choices[0].message.content
    return _parse_filled_fields(generated, fields)


def _parse_filled_fields(text: str, original_fields: list[dict]) -> list[FilledField]:
    clean = text.strip()
    if "```json" in clean:
        clean = clean.split("```json")[1].split("```")[0].strip()
    elif "```" in clean:
        clean = clean.split("```")[1].split("```")[0].strip()

    start = clean.find("[")
    end = clean.rfind("]") + 1
    if start == -1 or end == 0:
        # Fallback — return all fields as MISSING
        return _fallback_fields(original_fields)

    data = json.loads(clean[start:end])

    # Build lookup from original fields for label
    label_map = {f["key"]: f["label"] for f in original_fields}

    result = []
    for item in data:
        key = item.get("key", "")
        result.append(FilledField(
            key=key,
            label=label_map.get(key, key),
            value=item.get("value", ""),
            confidence=item.get("confidence", CONFIDENCE_MISSING),
            source=item.get("source", ""),
            note=item.get("note", ""),
        ))
    return result


def _fallback_fields(fields: list[dict]) -> list[FilledField]:
    return [
        FilledField(
            key=f["key"],
            label=f["label"],
            value="",
            confidence=CONFIDENCE_MISSING,
            source="",
            note="Could not auto-fill — please complete manually",
        )
        for f in fields
    ]
