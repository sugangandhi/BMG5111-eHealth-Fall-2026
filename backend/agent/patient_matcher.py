import json
import os
import re
import requests
from openai import OpenAI
from fhir.patient_loader import _load as load_fhir_patients, list_patients
from db.database import log_activity

# AI Client configuration (supports OPENAI_API_KEY on cloud/Render or LOCAL_AI_URL on local machine)
_client = None
MODEL = 'gemma2:2b'
try:
    if os.getenv('OPENAI_API_KEY'):
        _client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))
        MODEL = os.getenv('OPENAI_MODEL', 'gpt-4o-mini')
    elif os.getenv('LOCAL_AI_URL'):
        _client = OpenAI(base_url=os.getenv('LOCAL_AI_URL'), api_key=os.getenv('LOCAL_AI_KEY', 'local'))
        MODEL = os.getenv('LOCAL_AI_MODEL', 'gemma2:2b')
    else:
        _base_url = 'http://localhost:11434/v1'
        _client = OpenAI(base_url=_base_url, api_key='local')
        MODEL = 'gemma2:2b'
except Exception as e:
    print(f"[WhatsApp] AI client initialization note: {e}")
    _client = None

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

def resolve_meta_phone_number_id(token: str):
    """
    If only WHATSAPP_TOKEN is provided without WHATSAPP_PHONE_NUMBER_ID,
    automatically query Meta Graph API to discover the registered phone number ID.
    """
    phone_id = os.getenv('WHATSAPP_PHONE_NUMBER_ID')
    if phone_id:
        return phone_id
    if not token or not token.startswith('EAA'):
        return None
    try:
        headers = {"Authorization": f"Bearer {token}"}
        resp = requests.get("https://graph.facebook.com/v20.0/me/phone_numbers", headers=headers, timeout=5)
        if resp.status_code == 200:
            data = resp.json().get('data', [])
            if data and 'id' in data[0]:
                discovered = data[0]['id']
                print(f"[WhatsApp] Auto-discovered Phone Number ID from token: {discovered}")
                os.environ['WHATSAPP_PHONE_NUMBER_ID'] = discovered
                return discovered
    except Exception as e:
        print(f"[WhatsApp] Note during phone ID auto-discovery: {e}")
    return None

def send_whatsapp_message(to_phone: str, message_text: str) -> bool:
    """
    Sends an outbound WhatsApp message using either:
    1. Meta WhatsApp Cloud API (WHATSAPP_TOKEN & WHATSAPP_PHONE_NUMBER_ID)
    2. Twilio WhatsApp API (TWILIO_ACCOUNT_SID & TWILIO_AUTH_TOKEN)
    3. Simulated dispatch (when keys are not yet configured)
    """
    token = os.getenv('WHATSAPP_TOKEN')
    phone_number_id = os.getenv('WHATSAPP_PHONE_NUMBER_ID') or resolve_meta_phone_number_id(token)
    
    # Option 1: Meta WhatsApp Cloud API
    if token and phone_number_id:
        clean_to = re.sub(r'\D', '', to_phone)
        if len(clean_to) == 10:
            clean_to = '1' + clean_to  # default North American country code

        url = f"https://graph.facebook.com/v20.0/{phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json"
        }
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_to,
            "type": "text",
            "text": { "body": message_text }
        }

        try:
            resp = requests.post(url, headers=headers, json=payload, timeout=6)
            if resp.status_code in [200, 201]:
                print(f"[WhatsApp] Automated reply sent via Meta to {clean_to}")
                return True
            else:
                print(f"[WhatsApp] Meta API returned {resp.status_code}: {resp.text}")
                return False
        except Exception as err:
            print(f"[WhatsApp] Failed to dispatch Meta API message: {err}")
            return False

    # Option 2: Twilio WhatsApp Fallback
    twilio_sid = os.getenv('TWILIO_ACCOUNT_SID')
    twilio_auth = os.getenv('TWILIO_AUTH_TOKEN')
    twilio_from = os.getenv('TWILIO_PHONE_NUMBER', 'whatsapp:+14155238886')
    if twilio_sid and twilio_auth:
        clean_to = re.sub(r'\D', '', to_phone)
        if len(clean_to) == 10:
            clean_to = '1' + clean_to
        to_str = f"whatsapp:+{clean_to}"
        url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
        try:
            resp = requests.post(url, data={"From": twilio_from, "To": to_str, "Body": message_text}, auth=(twilio_sid, twilio_auth), timeout=6)
            if resp.status_code in [200, 201]:
                print(f"[WhatsApp] Automated reply sent via Twilio to {to_str}")
                return True
            else:
                print(f"[WhatsApp] Twilio returned {resp.status_code}: {resp.text}")
                return False
        except Exception as err:
            print(f"[WhatsApp] Twilio dispatch error: {err}")
            return False

    # Option 3: Simulation Fallback
    print(f"[WhatsApp Simulation] Automated reply to {to_phone}: {message_text}")
    return True

async def process_whatsapp_message(sender_phone: str, text_body: str) -> dict:
    """
    Core handler for inbound WhatsApp messages:
    1. Matches patient by phone number or regex/NLP extraction (Name/DOB).
    2. Extracts clinical entities and home vitals.
    3. Persists to patient EHR and Activity Log.
    4. Dispatches an automated confirmation back to patient's WhatsApp.
    Returns a dictionary summarizing execution for testing/simulations.
    """
    print(f'[WhatsApp Inbound] Phone={sender_phone}: "{text_body}"')
    
    # 1. Primary Match: Match by sender phone number
    matched_patient = match_patient_by_phone(sender_phone)
    
    # 2. Fallback Match: Check name patterns directly in text
    all_patients = load_fhir_patients()
    if not matched_patient:
        lower_msg = text_body.lower()
        for p in all_patients:
            p_text = p.get('name', {}).get('text', '').lower()
            if p_text and p_text in lower_msg:
                matched_patient = p
                print(f"[WhatsApp] Direct match by name in text: {p['name']['text']}")
                break

    # 3. Fallback Match: Extract Name & DOB via LLM if available and still unmatched
    if not matched_patient and _client:
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
                for p in all_patients:
                    if name.lower() in p['name']['text'].lower():
                        matched_patient = p
                        print(f"[WhatsApp] LLM matched patient: {p['name']['text']}")
                        break
        except Exception as e:
            print(f'[WhatsApp] NLP fallback failed: {e}')

    # 4. Extract clinical vitals (BP, HR, Glucose)
    vitals = extract_vitals_from_text(text_body)

    # 5. Update EHR & Log Activity
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

        # 6. Formulate automated clinical confirmation
        first_name = matched_patient['name'].get('given', [p_name])[0]
        if vitals:
            vitals_desc = ", ".join([f"{k.upper()}: {v}" for k, v in vitals.items()])
            reply_text = f"Hello {first_name}, thank you for updating e-Hospital. Your readings ({vitals_desc}) have been recorded directly into your patient chart."
        else:
            reply_text = f"Hello {first_name}, we have received your message and logged it into your e-Hospital medical record. Our clinical team has been notified."
            
        delivered = send_whatsapp_message(sender_phone, reply_text)
        return {
            "status": "success",
            "matched": True,
            "patient_name": p_name,
            "patient_id": p_id,
            "vitals_extracted": vitals,
            "reply_text": reply_text,
            "delivered": delivered
        }
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
        delivered = send_whatsapp_message(sender_phone, reply_text)
        return {
            "status": "unregistered",
            "matched": False,
            "patient_name": "Unregistered Contact",
            "patient_id": "UNKNOWN",
            "vitals_extracted": vitals,
            "reply_text": reply_text,
            "delivered": delivered
        }
