from __future__ import annotations

from datetime import datetime, timedelta
import os
import random
import re
from typing import Any
import requests
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from src.backend.clients.ehospital_client import (
    fetch_ehospital_table,
    write_ehospital_table_row,
)
from src.backend.core.logging import get_backend_logger

logger = get_backend_logger()

# In-memory OTP storage: phone_key -> {"code": "123456", "expires_at": datetime, "attempts": 0}
_OTP_STORE: dict[str, dict[str, Any]] = {}
OTP_VALIDITY_MINUTES = 10
MAX_ATTEMPTS = 5


def normalize_phone(phone_str: str) -> str:
    """Extracts digits from phone string."""
    digits = re.sub(r"\D", "", str(phone_str or ""))
    return digits


def get_phone_key(phone_str: str) -> str:
    """Returns the last 10 digits as the lookup key."""
    digits = normalize_phone(phone_str)
    return digits[-10:] if len(digits) >= 10 else digits


def dispatch_whatsapp_message(to_phone: str, message_text: str) -> bool:
    """
    Sends an outbound WhatsApp message using Meta Cloud API or Twilio.
    """
    clean_digits = normalize_phone(to_phone)
    if len(clean_digits) == 10:
        clean_digits = "1" + clean_digits

    token = os.getenv("WHATSAPP_TOKEN")
    phone_number_id = os.getenv("WHATSAPP_PHONE_NUMBER_ID")

    # 1. Meta WhatsApp Cloud API
    if token and phone_number_id:
        url = f"https://graph.facebook.com/v20.0/{phone_number_id}/messages"
        headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        payload = {
            "messaging_product": "whatsapp",
            "recipient_type": "individual",
            "to": clean_digits,
            "type": "text",
            "text": {"body": message_text},
        }
        try:
            resp = requests.post(url, headers=headers, json=payload, timeout=8, verify=False)
            if resp.status_code in [200, 201]:
                logger.info(f"[WhatsApp OTP] Delivered via Meta Cloud API to {clean_digits}")
                return True
            logger.warning(
                f"[WhatsApp OTP] Meta API returned {resp.status_code}: {resp.text}"
            )
            return False
        except Exception as e:
            logger.error(f"[WhatsApp OTP] Failed to send via Meta API: {e}")
            return False

    # 2. Twilio WhatsApp API Fallback
    twilio_sid = os.getenv("TWILIO_ACCOUNT_SID")
    twilio_auth = os.getenv("TWILIO_AUTH_TOKEN")
    twilio_from = os.getenv("TWILIO_PHONE_NUMBER", "whatsapp:+14155238886")
    if twilio_sid and twilio_auth:
        to_str = f"whatsapp:+{clean_digits}"
        url = f"https://api.twilio.com/2010-04-01/Accounts/{twilio_sid}/Messages.json"
        try:
            resp = requests.post(
                url,
                data={"From": twilio_from, "To": to_str, "Body": message_text},
                auth=(twilio_sid, twilio_auth),
                timeout=8,
                verify=False,
            )
            if resp.status_code in [200, 201]:
                logger.info(f"[WhatsApp OTP] Delivered via Twilio to {to_str}")
                return True
            logger.warning(f"[WhatsApp OTP] Twilio returned {resp.status_code}: {resp.text}")
            return False
        except Exception as e:
            logger.error(f"[WhatsApp OTP] Failed to send via Twilio: {e}")
            return False

    logger.error("[WhatsApp OTP] No active WhatsApp credentials configured.")
    return False


async def generate_and_send_whatsapp_otp(phone: str) -> dict[str, Any]:
    """Generates a 6-digit verification code and dispatches it via WhatsApp."""
    clean_digits = normalize_phone(phone)
    if len(clean_digits) < 10:
        return {
            "success": False,
            "error": "Invalid phone number. Please enter at least 10 digits.",
        }

    phone_key = get_phone_key(clean_digits)
    code = f"{random.randint(100000, 999999)}"
    expires_at = datetime.now() + timedelta(minutes=OTP_VALIDITY_MINUTES)

    _OTP_STORE[phone_key] = {
        "code": code,
        "full_phone": clean_digits,
        "expires_at": expires_at,
        "attempts": 0,
    }

    message_body = (
        f"🩺 *e-Hospital Login Verification*\n\n"
        f"Your verification code is: *{code}*\n\n"
        f"⏱️ Valid for {OTP_VALIDITY_MINUTES} minutes.\n"
        f"Never share this code with anyone."
    )

    dispatched = dispatch_whatsapp_message(clean_digits, message_body)
    if not dispatched:
        return {
            "success": False,
            "error": "Failed to send WhatsApp verification code. Please ensure your mobile number is registered with WhatsApp and includes your country code.",
        }

    return {
        "success": True,
        "message": f"Verification code sent via WhatsApp to {clean_digits[-4:].rjust(len(clean_digits), '*')}",
        "phone": clean_digits,
        "phone_key": phone_key,
        "expires_in_seconds": OTP_VALIDITY_MINUTES * 60,
    }


async def verify_whatsapp_otp(
    phone: str,
    code: str,
    selected_option: str = "Patient",
) -> dict[str, Any]:
    """
    Verifies the OTP code and resolves or creates the linked patient profile.
    """
    clean_digits = normalize_phone(phone)
    phone_key = get_phone_key(clean_digits)
    code_input = str(code or "").strip()

    record = _OTP_STORE.get(phone_key)
    if not record:
        return {
            "authenticated": False,
            "error": "No pending verification code found. Please request a new code.",
        }

    if datetime.now() > record["expires_at"]:
        _OTP_STORE.pop(phone_key, None)
        return {
            "authenticated": False,
            "error": "Verification code has expired. Please request a new code.",
        }

    if record["attempts"] >= MAX_ATTEMPTS:
        _OTP_STORE.pop(phone_key, None)
        return {
            "authenticated": False,
            "error": "Too many invalid attempts. Please request a new code.",
        }

    if record["code"] != code_input:
        record["attempts"] += 1
        remaining = MAX_ATTEMPTS - record["attempts"]
        return {
            "authenticated": False,
            "error": f"Invalid verification code. {remaining} attempt(s) remaining.",
        }

    # Verification succeeded: clean up OTP
    _OTP_STORE.pop(phone_key, None)

    # Resolve or Sync Patient from Central EMR database
    patient_id: int | None = None
    patient_name: str | None = None
    patient_email: str | None = None

    try:
        patients = await fetch_ehospital_table("patients_registration")
        for p in patients:
            p_phone = normalize_phone(str(p.get("phone_number") or p.get("contact_info") or ""))
            if p_phone and p_phone.endswith(phone_key):
                raw_id = p.get("patient_id") or p.get("id")
                patient_id = int(raw_id) if raw_id is not None else None
                patient_name = p.get("name") or p.get("FName")
                patient_email = p.get("email") or p.get("contact_info")
                break
    except Exception as e:
        logger.warning(f"[WhatsApp OTP] Error querying central patients table: {e}")

    # If patient is not yet registered in Central EMR, automatically register them
    if patient_id is None:
        try:
            new_patient_payload = {
                "name": f"Patient ({phone_key[-4:]})",
                "phone_number": clean_digits,
                "gender": "Other",
                "dob": "1990-01-01",
                "contact_info": f"{clean_digits}@whatsapp.ehospital.org",
            }
            created_resp = await write_ehospital_table_row("patients_registration", new_patient_payload)
            created_data = created_resp.get("data", created_resp) if isinstance(created_resp, dict) else {}
            if isinstance(created_data, dict) and created_data.get("patient_id"):
                patient_id = int(created_data["patient_id"])
                patient_name = created_data.get("name") or f"Patient ({phone_key[-4:]})"
                patient_email = created_data.get("contact_info")
                logger.info(f"[WhatsApp OTP] Registered new patient #{patient_id} for phone {clean_digits}")
        except Exception as e:
            logger.warning(f"[WhatsApp OTP] Error auto-registering patient in central table: {e}")

    # Fallback ID derivation if database is temporarily unreachable
    if patient_id is None:
        patient_id = int("9" + phone_key[-4:])
        patient_name = f"Patient {phone_key[-4:]}"
        patient_email = f"patient_{phone_key}@ehospital.org"

    return {
        "authenticated": True,
        "patient_id": patient_id,
        "user_id": patient_id,
        "username": patient_name or f"Patient {phone_key[-4:]}",
        "name": patient_name or f"Patient {phone_key[-4:]}",
        "email": patient_email or f"patient_{phone_key}@ehospital.org",
        "phone": clean_digits,
        "selectedOption": selected_option or "Patient",
        "token": f"wa-token-{patient_id}-{phone_key}",
    }
