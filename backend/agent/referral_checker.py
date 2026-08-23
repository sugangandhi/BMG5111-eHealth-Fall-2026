import os
import json
from openai import OpenAI

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

# Example hardcoded clinic criteria that the AI will use to judge
CRITERIA = {
    "Cardiology": "Requires recent ECG (within 6 months) and detailed list of current cardiac medications. Must state clear reason for consult.",
    "Neurology": "Requires recent MRI or CT scan of the head/spine. Must include a clear neurological exam summary.",
    "Orthopedics": "Requires recent X-ray of the affected joint/bone. Physiotherapy must have been attempted unless acute trauma."
}

def check_referral(text: str, specialty: str) -> dict:
    specialty_criteria = CRITERIA.get(specialty, "Must include a clear reason for consult and patient medical history.")
    
    prompt = f"""You are a specialist clinic gatekeeper evaluating an incoming referral letter.
Target Specialty: {specialty}
Required Criteria for acceptance: {specialty_criteria}

Read the referral text below and extract key clinical entities, then determine if it meets the criteria.
Return ONLY valid JSON in this format:
{{
  "status": "ACCEPTED" or "REJECTED" or "MISSING_INFO",
  "reason": "Explain why it was accepted, rejected, or what is missing.",
  "missing_items": ["Item 1", "Item 2"],
  "blood_group": "Extracted blood group (e.g. 'O+', 'A-') or 'Not provided'",
  "extracted_scans": ["Scan 1", "Scan 2"], 
  "clinical_summary": "A concise 1-sentence TL;DR of the patient's condition."
}}

REFERRAL TEXT:
{text[:5000]}
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
        
        return json.loads(content)
    except Exception as e:
        print(f"Error checking referral: {e}")
        return {
            "status": "MISSING_INFO",
            "reason": "Error calling AI. Manual review required.",
            "missing_items": ["Manual Review"],
            "blood_group": "Unknown",
            "extracted_scans": [],
            "clinical_summary": "Error processing referral text."
        }
