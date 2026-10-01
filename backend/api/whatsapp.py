import os
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
        "webhook_endpoint": "/api/whatsapp/webhook"
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
    Receives inbound messages from Meta WhatsApp Business Cloud API.
    """
    from agent.patient_matcher import process_whatsapp_message
    try:
        body = await request.json()
    except Exception:
        body = {}

    try:
        if body.get('object') == 'whatsapp_business_account':
            for entry in body.get('entry', []):
                for change in entry.get('changes', []):
                    value = change.get('value', {})
                    messages = value.get('messages', [])
                    if messages:
                        msg = messages[0]
                        sender_phone = msg.get('from')
                        text_body = msg.get('text', {}).get('body', '')
                        if sender_phone and text_body:
                            await process_whatsapp_message(sender_phone, text_body)
        return {'status': 'ok'}
    except Exception as e:
        print(f'Error processing WhatsApp webhook: {e}')
        return {'status': 'error', 'detail': str(e)}
