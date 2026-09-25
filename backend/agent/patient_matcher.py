import json
import os
from openai import OpenAI
from fhir.patient_loader import list_patients, get_patient
from db.database import log_activity

_base_url = os.getenv('LOCAL_AI_URL', 'http://localhost:11434/v1')
_client = OpenAI(base_url=_base_url, api_key='local')
MODEL = 'gemma2:2b'

_PROMPT = """You are a medical receptionist assistant.
Extract the patient name and date of birth from the following chat message.
Respond ONLY with a valid JSON object in this format:
{{
  "name": "extracted name or null",
  "dob": "extracted DOB (YYYY-MM-DD) or null"
}}

Message: {message}"""

async def process_whatsapp_message(sender_phone: str, text_body: str):
    print(f'Received WhatsApp from {sender_phone}: {text_body}')
    
    prompt = _PROMPT.format(message=text_body)
    try:
        response = _client.chat.completions.create(
            model=MODEL,
            messages=[{'role': 'user', 'content': prompt}],
            response_format={'type': 'json_object'},
            temperature=0.0
        )
        extracted = json.loads(response.choices[0].message.content)
        name = extracted.get('name')
        dob = extracted.get('dob')
        
        print(f'Extracted: Name={name}, DOB={dob}')
        
        all_patients = list_patients()
        matched_patient = None
        for p in all_patients:
            if name and name.lower() in p['name'].lower():
                matched_patient = p
                break
        
        if matched_patient:
            print(f"Matched Patient: {matched_patient['name']}")
            log_activity(
                action='whatsapp_message_received',
                description=f'Message from {sender_phone}',
                patient_name=matched_patient['name'],
                detail=f'WHATSAPP: {text_body}',
                color='green'
            )
        else:
            print('No patient matched.')
            log_activity(
                action='whatsapp_message_received',
                description=f'Message from {sender_phone}',
                patient_name='Unknown',
                detail=f'WHATSAPP: {text_body}',
                color='yellow'
            )
    except Exception as e:
        print(f'Error processing NLP matcher: {e}')
