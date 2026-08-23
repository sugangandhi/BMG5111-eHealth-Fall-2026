import os
import json
from openai import OpenAI

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

def summarize_inbound_note(text: str) -> dict:
    prompt = f"""You are a clinical assistant. Summarize the following inbound specialist report.
Return ONLY valid JSON in this format:
{{
  "patient_name": "Extracted Patient Name",
  "summary": "High-level summary of what happened.",
  "key_changes": ["Change 1", "Change 2"],
  "followup_actions": ["Follow up 1", "Follow up 2"],
  "missing_info": ["Missing info 1"],
  "suggested_questions": ["Question 1 about the report", "Question 2 about the report"],
  "recommended_appointment": {{
      "needed": true,
      "timeframe": "e.g., 30 days, 6 months, 2 weeks",
      "type": "e.g., Neurological re-evaluation"
  }}
}}

REPORT:
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
        
        return json.loads(content)
    except Exception as e:
        print(f"Error summarizing inbound note: {e}")
        return {
            "patient_name": "Unknown Patient",
            "summary": "Error generating summary.",
            "key_changes": [],
            "followup_actions": [],
            "missing_info": [],
            "suggested_questions": ["What is the main diagnosis?"],
            "recommended_appointment": { "needed": False, "timeframe": "", "type": "" }
        }
