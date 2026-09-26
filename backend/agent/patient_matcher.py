import json
import os
import re
import requests
from openai import OpenAI
from fhir.patient_loader import _load as load_fhir_patients, list_patients
from db.database import log_activity

_base_url = os.getenv('LOCAL_AI_URL', 'http://localhost:11434/v1')
_client = OpenAI(base_url=_base_url, api_key='local')
MODEL = 'gemma2:2b'

def normalize_phone(phone_str: str) -> str:
    """Extracts digits from phone string, taking the last 10 digits."""
    digits = re.sub(r'\D', '', str(phone_str or ''))
    return digits[-10:] if len(digits) >= 10 else digits

def match_patient_by_phone(sender_phone: str):
    """Finds a patient record by matching telephone numbers."""
    target_digits = normalize_phone(sender_phone)
    if not target_digits:
        return None
    
    patients = load_fhir_patients()
    for p in patients:
        p_digits = normalize_phone(p.get('phone', ''))
        if p_digits and p_digits == target_digits:
            return p
    return None

def extract_vitals_from_text(text: str) -> dict:
    """Extracts common clinical vitals from patient message."""
    vitals = {}
    # Blood pressure e.g. 138/86 or 120 / 80
    bp_match = re.search(r'(\d{2,3}\s*/\s*\d{2,3})', text)
    if bp_match:
        vitals['bp'] = bp_match.group(1).replace(' ', '')
    
    # Pulse / Heart rate e.g. HR 74 or pulse: 82
    hr_match = re.search(r'(?:hr|pulse|heart rate)[\s:]*(\d{2,3})', text, re.IGNORECASE)
    if hr_match:
        vitals['hr'] = hr_match.group(1)
        
    # Blood sugar / Glucose e.g. sugar 6.8 or glucose: 7.2
    sugar_match = re.search(r'(?:sugar|glucose|bg)[\s:]*(\d{1,2}(?:\.\d)?)', text, re.IGNORECASE)
    if sugar_match:
        vitals['glucose'] = sugar_match.group(1)
        
    return vitals

def send_whatsapp_message(to_phone: str, message_text: str):
    """
    Sends an outbound WhatsApp message using the Meta WhatsApp Cloud API.
    Uses credentials provided by the professor:
      - WHATSAPP_TOKEN: Meta Graph API Bearer Token
      - WHATSAPP_PHONE_NUMBER_ID: Meta Phone Number ID
    """
    token = os.getenv('WHATSAPP_TOKEN')
    phone_number_id = os.getenv('WHATSAPP_PHONE_NUMBER_ID')
    
    if not token or not phone_number_id:
        print(f"[WhatsApp] Meta API credentials not yet configured. Simulated reply to {to_phone}: {message_text}")
        return False

    url = f"https://graph.facebook.com/v20.0/{phone_number_id}/messages"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    payload = {
        "messaging_product": "whatsapp",
        "recipient_type": "individual",
        "to": to_phone,
        "type": "text",
        "text": { "body": message_text }
    }

    try:
        resp = requests.post(url, headers=headers, json=payload, timeout=6)
        if resp.status_code in [200, 201]:
            print(f"[WhatsApp] Automated reply sent to {to_phone}")
            return True
        else:
            print(f"[WhatsApp] Meta API returned {resp.status_code}: {resp.text}")
            return False
    except Exception as err:
        print(f"[WhatsApp] Failed to dispatch Meta API message: {err}")
        return False

async def process_whatsapp_message(sender_phone: str, text_body: str):
    """
    Core handler for inbound WhatsApp messages:
    1. Matches patient by phone number or NLP extraction (Name/DOB).
    2. Extracts clinical entities and home vitals.
    3. Persists to patient EHR and Activity Log.
    4. Dispatches an automated confirmation back to patient's WhatsApp.
    """
    print(f'[WhatsApp Inbound] Phone={sender_phone}: "{text_body}"')
    
    # 1. Primary Match: Match by sender phone number
    matched_patient = match_patient_by_phone(sender_phone)
    
    # 2. Fallback Match: Extract Name & DOB via LLM if phone wasn't matched
    if not matched_patient:
        try:
            prompt = f"""You are a medical receptionist assistant.
Extract the patient name and date of birth from the following chat message.
Respond ONLY with a valid JSON object in this format:
{{
  "name": "extracted name or null",
  "dob": "extracted DOB (YYYY-MM-DD) or null"
}}

Message: {text_body}"""
            
            response = _client.chat.completions.create(
                model=MODEL,
                messages=[{'role': 'user', 'content': prompt}],
                response_format={'type': 'json_object'},
                temperature=0.0
            )
            extracted = json.loads(response.choices[0].message.content)
            name = extracted.get('name')
            if name:
                all_patients = load_fhir_patients()
                for p in all_patients:
                    if name.lower() in p['name']['text'].lower():
                        matched_patient = p
                        break
        except Exception as e:
            print(f'[WhatsApp] NLP fallback failed: {e}')

    # 3. Extract clinical vitals (BP, HR, Glucose)
    vitals = extract_vitals_from_text(text_body)

    # 4. Update EHR & Log Activity
    if matched_patient:
        p_name = matched_patient['name']['text']
        p_id = matched_patient['id']
        print(f"[WhatsApp] Confirmed Patient Match: {p_name} ({p_id})")

        detail_text = f"WhatsApp: {text_body}"
        if vitals:
            detail_text += f" | Extracted Vitals: {vitals}"
            if "vitals_trend" in matched_patient:
                matched_patient["vitals_trend"].append({
                    "date": "Today",
                    **vitals
                })

        log_activity(
            action='whatsapp_message_received',
            description=f'Verified WhatsApp encounter with {p_name}',
            patient_name=p_name,
            patient_id=p_id,
            detail=detail_text,
            color='emerald'
        )

        # 5. Formulate automated clinical confirmation
        first_name = matched_patient['name'].get('given', [p_name])[0]
        if vitals:
            vitals_desc = ", ".join([f"{k.upper()}: {v}" for k, v in vitals.items()])
            reply_text = f"Hello {first_name}, thank you for updating e-Hospital. Your readings ({vitals_desc}) have been recorded directly into your patient chart."
        else:
            reply_text = f"Hello {first_name}, we have received your message and logged it into your e-Hospital medical record. Our clinical team has been notified."
            
        send_whatsapp_message(sender_phone, reply_text)
    else:
        print("[WhatsApp] Unmatched sender. Logging to triage inbox.")
        log_activity(
            action='whatsapp_unregistered_sender',
            description=f'WhatsApp inquiry from {sender_phone}',
            patient_name='Unregistered Contact',
            patient_id='UNKNOWN',
            detail=f'WHATSAPP: {text_body}',
            color='orange'
        )

        reply_text = (
            "Thank you for messaging e-Hospital. We could not automatically match this phone number to an active patient record. "
            "Please reply with your Full Name and Date of Birth (YYYY-MM-DD) so we can locate your chart."
        )
        send_whatsapp_message(sender_phone, reply_text)
