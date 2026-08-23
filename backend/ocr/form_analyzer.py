import os
import json
from openai import OpenAI
from pydantic import BaseModel

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

class FormField(BaseModel):
    key: str
    label: str
    field_type: str = "text"
    required: bool = True
    what_it_needs: str = ""
    fhir_hint: str = ""
    options: list = []

class FormSchema(BaseModel):
    form_type: str
    issuer: str
    purpose: str
    fields: list[FormField]

def analyze_form_structure(text: str) -> FormSchema:
    prompt = f"""You are a medical form analyzer. 
Analyze the following form text and identify its schema.
Return ONLY valid JSON in this format:
{{
  "form_type": "Type of form",
  "issuer": "Who issued the form",
  "purpose": "Purpose of the form",
  "fields": [
    {{
      "key": "unique_id_for_field",
      "label": "Human readable label",
      "what_it_needs": "Description of what belongs in this field",
      "fhir_hint": "FHIR path if applicable"
    }}
  ]
}}

FORM TEXT:
{text[:10000]}
"""
    try:
        response = _client.chat.completions.create(
            model=MODEL,
            response_format={ "type": "json_object" },
            messages=[{"role": "user", "content": prompt}],
            temperature=0.1
        )
        content = response.choices[0].message.content
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].strip()
        
        data = json.loads(content)
        return FormSchema(**data)
    except Exception as e:
        print(f"Error analyzing form structure: {e}")
        return FormSchema(form_type="Unknown", issuer="Unknown", purpose="Unknown", fields=[])
