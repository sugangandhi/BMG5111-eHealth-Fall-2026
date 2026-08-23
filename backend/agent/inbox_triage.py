import os
import json
from openai import OpenAI

_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

def triage_inbox_message(text: str) -> dict:
    prompt = f"""You are a clinical AI agent performing triage on incoming secure messages and e-faxes.
Read the message and determine if it is an EMERGENCY (e.g. chest pain, heart attack, stat referral, severe distress) or ROUTINE (e.g. prescription refill, admin request, standard referral).

Return ONLY valid JSON in this format:
{{
  "priority": "EMERGENCY" or "ROUTINE",
  "summary": "A brief 1-2 sentence summary of the message.",
  "suggested_action": "What the staff should do next (e.g. 'Call patient immediately' or 'Forward to Dr. Smith')"
}}

MESSAGE:
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
        print(f"Error triaging inbox message: {e}")
        # Simple fallback heuristic if model fails
        lower_text = text.lower()
        is_emergency = any(word in lower_text for word in ["heart attack", "chest pain", "stat", "urgent", "emergency", "stroke"])
        return {
            "priority": "EMERGENCY" if is_emergency else "ROUTINE",
            "summary": "Error calling AI. See raw message.",
            "suggested_action": "Review manually"
        }
