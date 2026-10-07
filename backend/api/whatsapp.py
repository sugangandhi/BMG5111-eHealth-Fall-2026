import os
import asyncio
import requests
from typing import Optional, Dict, Any, List
from fastapi import APIRouter, Request, HTTPException
from pydantic import BaseModel

router = APIRouter(tags=['whatsapp'])

WHATSAPP_VERIFY_TOKEN = os.getenv('WHATSAPP_VERIFY_TOKEN', 'ehospital_verified_2026')

class SimulateMessageRequest(BaseModel):
    phone: str = "613-555-0192"
    message: str = "Hi Doctor, this is Sarah Khan. My blood pressure this morning is 138/88 and my heart rate is 78."

@router.get('/api/whatsapp/status')
async def get_whatsapp_status():
    """
    Returns the real-time configuration status of the WhatsApp integration,
    including webhook callback endpoints and cloud environment details.
    """
    token = os.getenv('WHATSAPP_TOKEN')
    phone_id = os.getenv('WHATSAPP_PHONE_NUMBER_ID')
    if not phone_id and token and token.startswith('EAA'):
        from agent.patient_matcher import resolve_meta_phone_number_id
        phone_id = resolve_meta_phone_number_id(token)

    display_phone = os.getenv('WHATSAPP_DISPLAY_PHONE', '1234567890')
    has_meta = bool(token and phone_id)
    has_twilio = bool(os.getenv('TWILIO_ACCOUNT_SID') and os.getenv('TWILIO_AUTH_TOKEN'))
    
    masked_phone_id = None
    if phone_id:
        masked_phone_id = phone_id[:4] + "••••" + phone_id[-4:] if len(phone_id) > 8 else phone_id

    return {
        "configured": has_meta or has_twilio,
        "provider": "meta" if has_meta else ("twilio" if has_twilio else "simulated"),
        "phone_number_id": masked_phone_id,
        "display_phone": display_phone,
        "verify_token": WHATSAPP_VERIFY_TOKEN,
        "webhook_endpoint": "/api/whatsapp/webhook",
        "poller_active": bool(_poller_task and not _poller_task.done()),
        "poller_indexed_messages": len(_processed_twilio_sids)
    }

class SendWhatsAppRequest(BaseModel):
    phone: str
    message: str
    patient_id: Optional[str] = None
    patient_name: Optional[str] = None
    doctor_name: Optional[str] = "Attending Physician"

@router.get('/api/whatsapp/thread/{identifier}')
async def get_patient_whatsapp_thread(identifier: str):
    """
    Returns the real-time two-way WhatsApp message thread for the specified patient or phone number.
    Used by the In-Portal WhatsApp Messenger.
    """
    from agent.inbox_manager import get_whatsapp_thread
    thread = get_whatsapp_thread(identifier)
    return {
        "identifier": identifier,
        "count": len(thread),
        "messages": thread
    }

@router.post('/api/whatsapp/send')
async def send_doctor_whatsapp_reply(req: SendWhatsAppRequest):
    """
    Sends an official outbound WhatsApp reply directly from the In-Portal Messenger to the patient's phone.
    Logs the encounter to the persistent thread, EHR activity trail, and Central Cloud MySQL table.
    """
    from agent.patient_matcher import send_whatsapp_message
    from agent.inbox_manager import record_whatsapp_thread_message
    from db.database import log_activity
    import datetime

    # 1. Dispatch through configured gateway (Meta Cloud API / Twilio / Simulation)
    delivered = send_whatsapp_message(req.phone, req.message)

    # 2. Record to local persistent thread
    recorded = record_whatsapp_thread_message(
        identifier=req.phone,
        role="doctor",
        sender_name=req.doctor_name or "Attending Physician",
        text=req.message
    )

    # 3. Log EHR activity
    p_name = req.patient_name or "Patient"
    log_activity(
        action="whatsapp_doctor_replied",
        description=f"In-Portal WhatsApp reply sent to {p_name}",
        patient_name=p_name,
        patient_id=req.patient_id or "UNKNOWN",
        detail=f"Outbound WhatsApp message via Clinic Gateway: '{req.message}'",
        color="emerald"
    )

    # 4. Sync to Central Cloud MySQL EMR table message_pat_to_doctor
    try:
        from integrations.central_clinical_api import post_patient_message_to_doctor, find_central_patient
        c_patient = find_central_patient(name=p_name, phone=req.phone)
        c_p_id = c_patient["patient_id"] if c_patient else 1
        post_patient_message_to_doctor(
            patient_id=c_p_id,
            message=f"[Doctor Reply from {req.doctor_name}] {req.message}",
            doctor_id=1,
            is_urgent=False
        )
    except Exception as e:
        print(f"[WhatsApp In-Portal Send] Central Cloud sync note: {e}")

    return {
        "status": "sent",
        "delivered": delivered,
        "message": recorded,
        "timestamp": datetime.datetime.now().isoformat()
    }

@router.post('/api/whatsapp/simulate')
async def simulate_whatsapp_message(req: SimulateMessageRequest):
    """
    Direct simulation endpoint for testing the complete NLP vital extraction,
    FHIR patient chart update, and automated clinical reply without needing Meta webhooks.
    """
    from agent.patient_matcher import process_whatsapp_message
    try:
        result = await process_whatsapp_message(req.phone, req.message)
        return result
    except Exception as e:
        print(f"Error simulating WhatsApp encounter: {e}")
        return {
            "status": "error",
            "detail": str(e)
        }

@router.get('/webhook/whatsapp')
@router.get('/webhook/whatsapp/')
@router.get('/api/whatsapp/webhook')
async def verify_webhook(request: Request):
    """
    Verification endpoint required by Meta WhatsApp Cloud API.
    Meta queries this with hub.mode, hub.verify_token, and hub.challenge.
    """
    hub_mode = request.query_params.get('hub.mode')
    hub_challenge = request.query_params.get('hub.challenge')
    hub_verify_token = request.query_params.get('hub.verify_token')

    if hub_mode == 'subscribe' and hub_verify_token == WHATSAPP_VERIFY_TOKEN:
        print(f"[WhatsApp] Webhook verified successfully with token: {hub_verify_token}")
        return int(hub_challenge) if hub_challenge and hub_challenge.isdigit() else hub_challenge
    
    print(f"[WhatsApp] Webhook verification failed. Received token: {hub_verify_token}, Expected: {WHATSAPP_VERIFY_TOKEN}")
    raise HTTPException(status_code=403, detail='Verification failed')

@router.post('/webhook/whatsapp')
@router.post('/webhook/whatsapp/')
@router.post('/api/whatsapp/webhook')
async def receive_message(request: Request):
    """
    Receives inbound messages from either Meta WhatsApp Cloud API or Twilio WhatsApp Sandbox.
    """
    from agent.patient_matcher import process_whatsapp_message

    sender_phone = None
    text_body = None

    content_type = request.headers.get('content-type', '')
    if 'application/x-www-form-urlencoded' in content_type or 'multipart/form-data' in content_type:
        # Twilio standard form-encoded webhook
        try:
            form = await request.form()
            twilio_from = form.get('From', '')
            twilio_body = form.get('Body', '')
            if twilio_from and twilio_body:
                sender_phone = str(twilio_from).replace('whatsapp:', '').strip()
                text_body = str(twilio_body).strip()
        except Exception as e:
            print(f"[WhatsApp Webhook] Error reading form data: {e}")
    else:
        # JSON payload (Meta Cloud API or Twilio JSON)
        try:
            body = await request.json()
        except Exception:
            body = {}

        if body.get('object') == 'whatsapp_business_account':
            # Meta format
            for entry in body.get('entry', []):
                for change in entry.get('changes', []):
                    value = change.get('value', {})
                    messages = value.get('messages', [])
                    if messages:
                        msg = messages[0]
                        sender_phone = msg.get('from')
                        text_body = msg.get('text', {}).get('body', '')
        elif 'From' in body and 'Body' in body:
            # Twilio JSON format
            sender_phone = str(body.get('From', '')).replace('whatsapp:', '').strip()
            text_body = str(body.get('Body', '')).strip()

    if sender_phone and text_body:
        print(f"[WhatsApp Webhook Inbound] SENDER={sender_phone} BODY=\"{text_body}\"")
        result = await process_whatsapp_message(sender_phone, text_body)
        return {'status': 'ok', 'processed': True, 'result': result}

    return {'status': 'ok', 'processed': False}


# ── Twilio Real-Time Inbound Poller ──────────────────────────────────────────
# Enables zero-config, instant inbound message processing on Twilio accounts
# where custom webhooks in the console UI require paid account upgrades.

_processed_twilio_sids = set()
_poller_task = None

async def start_twilio_inbound_poller():
    """
    Background worker that continuously polls the Twilio REST API for inbound messages.
    Guarantees that any WhatsApp message sent from the user's phone to the Twilio number
    is instantly captured and processed by our clinical AI engine in real time.
    """
    global _processed_twilio_sids
    sid = os.getenv('TWILIO_ACCOUNT_SID')
    auth = os.getenv('TWILIO_AUTH_TOKEN')
    if not sid or not auth:
        print("[Twilio Poller] No credentials provided, poller skipped.")
        return

    print("[Twilio Poller] Initializing real-time inbound message poller...")
    
    # Pre-seed existing messages so we only process new incoming messages
    try:
        loop = asyncio.get_running_loop()
        url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json?Direction=inbound&PageSize=20"
        resp = await loop.run_in_executor(None, lambda: requests.get(url, auth=(sid, auth), timeout=6))
        if resp.status_code == 200:
            for m in resp.json().get('messages', []):
                msid = m.get('sid')
                if msid:
                    _processed_twilio_sids.add(msid)
            print(f"[Twilio Poller] Ready. Indexed {len(_processed_twilio_sids)} existing messages.")
    except Exception as e:
        print(f"[Twilio Poller] Pre-seed warning: {e}")

    while True:
        try:
            await asyncio.sleep(2.5)
            sid = os.getenv('TWILIO_ACCOUNT_SID')
            auth = os.getenv('TWILIO_AUTH_TOKEN')
            if not sid or not auth:
                continue

            url = f"https://api.twilio.com/2010-04-01/Accounts/{sid}/Messages.json?Direction=inbound&PageSize=10"
            loop = asyncio.get_running_loop()
            resp = await loop.run_in_executor(None, lambda: requests.get(url, auth=(sid, auth), timeout=5))

            if resp.status_code == 200:
                messages = resp.json().get('messages', [])
                # Process oldest new message first
                for m in reversed(messages):
                    msid = m.get('sid')
                    if msid and msid not in _processed_twilio_sids:
                        _processed_twilio_sids.add(msid)
                        body = str(m.get('body', '')).strip()
                        raw_from = m.get('from', '')
                        
                        # Filter out sandbox join activation codes
                        if 'join ' in body.lower():
                            continue

                        sender_phone = str(raw_from).replace('whatsapp:', '').strip()
                        text_body = body
                        if sender_phone and text_body:
                            print(f"\n⚡ [Twilio Inbound Poller] DETECTED INBOUND MESSAGE FROM {sender_phone}: \"{text_body}\"")
                            from agent.patient_matcher import process_whatsapp_message
                            await process_whatsapp_message(sender_phone, text_body)
        except Exception as poll_err:
            await asyncio.sleep(2.5)

