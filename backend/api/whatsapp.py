import os
from fastapi import APIRouter, Request, HTTPException

router = APIRouter(tags=['whatsapp'])

WHATSAPP_VERIFY_TOKEN = os.getenv('WHATSAPP_VERIFY_TOKEN', 'ehospital_verified_2026')

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
