"""
Combined form analysis + field filling in a single local AI call.
"""
import json
import os
from openai import OpenAI
from dataclasses import dataclass

from ocr.form_analyzer import FormSchema, FormField
from agent.field_mapper import FilledField, CONFIDENCE_MISSING

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

_PROMPT = """You are a medical office assistant helping a Canadian primary care physician complete a form.

PATIENT RECORD:
{patient_context}

FORM TEXT (OCR-extracted from uploaded document):
{ocr_text}

TASK: 
1. Read the FORM TEXT and identify the blank fields that need to be filled. 
2. Fill each of those fields using the PATIENT RECORD.

CRITICAL RULES:
- ONLY create fields that actually exist on the form. Do NOT dump the entire patient record. If the form only asks for 4 things, you must only return 4 fields.
- For the "key" and "label", you MUST extract the exact text from the form (e.g. "Patient Name", "DOB", "Reason for visit"). Do not invent your own labels or use placeholder names.

Return ONLY valid JSON — no explanation, no markdown fences, no trailing text:
{{
  "form_type": "Full name of the form",
  "issuer": "Organization that issues this form",
  "purpose": "One sentence: what this form is used for",
  "fields": [
    {{
      "key": "exact_form_text_identifier",
      "label": "Exact label text from the form",
      "value": "Value from patient record, or empty string if unknown",
      "confidence": "HIGH|MEDIUM|LOW|MISSING",
      "source": "Brief source (max 8 words)",
      "note": "Brief physician note (max 10 words, empty if none)"
    }}
  ]
}}
"""

def analyze_and_fill(ocr_text: str, patient_context: str) -> tuple[FormSchema, list[FilledField]]:
    prompt = _PROMPT.format(
        patient_context=patient_context,
        ocr_text=ocr_text[:6000],
    )
    try:
        response = _client.chat.completions.create(
            model=MODEL,
            response_format={ "type": "json_object" },
            messages=[
                {"role": "user", "content": prompt}
            ]
        )
        content = response.choices[0].message.content
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        return _parse_response(content)
    except Exception as e:
        print(f"Error in analyze_and_fill: {e}")
        return None, []


def _parse_response(text: str) -> tuple[FormSchema, list[FilledField]]:
    clean = text.strip()
    if "```json" in clean:
        clean = clean.split("```json")[1].split("```")[0].strip()
    elif "```" in clean:
        clean = clean.split("```")[1].split("```")[0].strip()

    start = clean.find("{")
    if start == -1:
        raise ValueError(f"No JSON in response: {text[:300]}")

    end = clean.rfind("}") + 1
    json_str = clean[start:end]

    try:
        data = json.loads(json_str)
    except json.JSONDecodeError:
        data = _recover_truncated(json_str)

    form_fields = []
    filled      = []

    for f in data.get("fields", []):
        key = f.get("key", "")
        form_fields.append(FormField(
            key=key,
            label=f.get("label", ""),
            field_type="text",
            required=True,
            what_it_needs="",
            fhir_hint="",
            options=[],
        ))
        filled.append(FilledField(
            key=key,
            label=f.get("label", ""),
            value=f.get("value", ""),
            confidence=f.get("confidence", CONFIDENCE_MISSING),
            source=f.get("source", ""),
            note=f.get("note", ""),
        ))

    schema = FormSchema(
        form_type=data.get("form_type", "Unknown Form"),
        issuer=data.get("issuer", ""),
        purpose=data.get("purpose", ""),
        fields=form_fields,
    )

    return schema, filled


def _recover_truncated(text: str) -> dict:
    outer = {"form_type": "Unknown Form", "issuer": "", "purpose": "", "fields": []}
    for key in ("form_type", "issuer", "purpose"):
        marker = f'"{key}"'
        idx = text.find(marker)
        if idx != -1:
            val_start = text.find('"', idx + len(marker) + 1)
            val_end   = text.find('"', val_start + 1)
            if val_start != -1 and val_end != -1:
                outer[key] = text[val_start+1:val_end]

    fields_idx = text.find('"fields"')
    if fields_idx == -1:
        return outer

    bracket = text.find('[', fields_idx)
    if bracket == -1:
        return outer

    complete = []
    depth = 0
    obj_start = None

    for pos, ch in enumerate(text[bracket + 1:], start=bracket + 1):
        if ch == '{':
            if depth == 0:
                obj_start = pos
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0 and obj_start is not None:
                try:
                    obj = json.loads(text[obj_start:pos + 1])
                    complete.append(obj)
                except json.JSONDecodeError:
                    pass
                obj_start = None

    outer["fields"] = complete
    return outer
