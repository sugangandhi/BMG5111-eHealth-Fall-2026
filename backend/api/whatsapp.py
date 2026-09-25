import os
from fastapi import APIRouter, Request, HTTPException

router = APIRouter(prefix='/webhook/whatsapp', tags=['whatsapp'])

WHATSAPP_VERIFY_TOKEN = os.getenv('WHATSAPP_VERIFY_TOKEN', 'hackers_healers_secret')

@router.get('/')
async def verify_webhook(request: Request):
    hub_mode = request.query_params.get('hub.mode')
    hub_challenge = request.query_params.get('hub.challenge')
    hub_verify_token = request.query_params.get('hub.verify_token')

    if hub_mode == 'subscribe' and hub_verify_token == WHATSAPP_VERIFY_TOKEN:
        return int(hub_challenge) if hub_challenge and hub_challenge.isdigit() else hub_challenge
    raise HTTPException(status_code=403, detail='Verification failed')

@router.post('/')
async def receive_message(request: Request):
    from agent.patient_matcher import process_whatsapp_message
    body = await request.json()
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
                            # Process in background or await
                            await process_whatsapp_message(sender_phone, text_body)
        return {'status': 'ok'}
    except Exception as e:
        print(f'Error processing WhatsApp webhook: {e}')
        return {'status': 'error'}

