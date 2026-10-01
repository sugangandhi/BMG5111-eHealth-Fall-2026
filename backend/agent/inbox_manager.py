import os
import json
import time
from pathlib import Path
from typing import List, Dict, Any, Optional
from urllib.parse import quote_plus

INBOX_FILE = Path(__file__).parent.parent / "inbox_store.json"

DEFAULT_MESSAGES = [
    {
        "id": 101,
        "type": "emergency",
        "sender": "Dr. James Smith (Cardiology)",
        "subject": "STAT Consult Result - Patient John Doe",
        "snippet": "- Patient John Doe presented with severe chest pain and elevated troponin levels. Diagnosed with acute myocardial infarction. Immediate transfer to CCU required. Please arrange stat follow-up.",
        "timestamp": "10:14 AM",
        "isUnread": True,
        "status": "pending",
        "hasAttachment": True,
        "starred": True
    },
    {
        "id": 102,
        "type": "rx",
        "sender": "Shoppers Drug Mart",
        "subject": "Prescription Refill Request",
        "snippet": "- Patient Mary Jane is requesting a 90-day refill for Metformin 500mg. Please authorize.",
        "timestamp": "Yesterday",
        "isUnread": True,
        "status": "pending",
        "hasAttachment": False,
        "starred": False
    },
    {
        "id": 103,
        "type": "discharge",
        "sender": "General Hospital ER",
        "subject": "Discharge Summary - Robert Lee",
        "snippet": "- Patient admitted for minor concussion following a slip and fall. CT scan clear. Discharged with instructions to rest and follow up with family physician in 1 week if headaches persist.",
        "timestamp": "May 20",
        "isUnread": False,
        "status": "pending",
        "hasAttachment": True,
        "starred": False
    },
    {
        "id": 104,
        "type": "inquiry",
        "sender": "Sarah Jenkins, RN",
        "subject": "Update on Clinical Research Assistant II",
        "snippet": "- Dear team, Thank you for the update regarding the Clinical Research Assistant II position. I appreciate the selection committee's time...",
        "timestamp": "Jul 7",
        "isUnread": False,
        "status": "resolved",
        "hasAttachment": False,
        "starred": False
    },
    {
        "id": 105,
        "type": "admin",
        "sender": "IT Support",
        "subject": "System Maintenance Notice",
        "snippet": "- Please be advised that the main EHR portal will undergo scheduled maintenance this Sunday between 2AM and 4AM EST.",
        "timestamp": "Jul 23",
        "isUnread": False,
        "status": "resolved",
        "hasAttachment": False,
        "starred": False
    }
]

# Ephemeral in-memory queue for real-time frontend polling
PENDING_SYNC_QUEUE: List[Dict[str, Any]] = []

def _load_messages() -> List[Dict[str, Any]]:
    if not INBOX_FILE.exists():
        _save_messages(DEFAULT_MESSAGES)
        return list(DEFAULT_MESSAGES)
    try:
        with open(INBOX_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"[InboxManager] Error reading inbox store: {e}")
        return list(DEFAULT_MESSAGES)

def _save_messages(messages: List[Dict[str, Any]]) -> None:
    try:
        with open(INBOX_FILE, "w", encoding="utf-8") as f:
            json.dump(messages, f, indent=2)
    except Exception as e:
        print(f"[InboxManager] Error saving inbox store: {e}")

def get_inbox_messages() -> List[Dict[str, Any]]:
    return _load_messages()

def add_inbox_message(msg: Dict[str, Any]) -> Dict[str, Any]:
    messages = _load_messages()
    # Check if duplicate ID exists
    messages = [m for m in messages if m.get("id") != msg.get("id")]
    messages.insert(0, msg)
    _save_messages(messages)
    PENDING_SYNC_QUEUE.append(msg)
    return msg

def get_sync_messages() -> List[Dict[str, Any]]:
    global PENDING_SYNC_QUEUE
    items = list(PENDING_SYNC_QUEUE)
    PENDING_SYNC_QUEUE.clear()
    return items

def update_inbox_status(msg_id: int, status: str) -> Optional[Dict[str, Any]]:
    messages = _load_messages()
    updated = None
    for m in messages:
        if m.get("id") == msg_id:
            m["status"] = status
            if "Doctor" in status or "Resolved" in status:
                m["isUnread"] = False
            updated = m
            break
    if updated:
        _save_messages(messages)
    return updated

def add_whatsapp_escalation(
    patient_name: str,
    patient_id: str,
    sender_phone: str,
    text_body: str,
    vitals: Optional[Dict[str, Any]] = None,
    urgency: str = "stat"
) -> Dict[str, Any]:
    """
    Creates a high-priority doctor escalation card for an inbound WhatsApp message
    where the patient asked for real doctor advice or reported concerning symptoms.
    """
    import re
    digits = re.sub(r'\D', '', sender_phone or '')
    clean_phone = ('1' + digits) if len(digits) == 10 else digits or '16135550192'

    vitals_parts = []
    if vitals:
        if vitals.get("bp"):
            vitals_parts.append(f"BP: {vitals['bp']}")
        if vitals.get("hr"):
            vitals_parts.append(f"HR: {vitals['hr']} bpm")
        if vitals.get("glucose"):
            vitals_parts.append(f"Glucose: {vitals['glucose']} mmol/L")
    vitals_str = ", ".join(vitals_parts) if vitals_parts else None

    # Pre-crafted direct continuation message for Dr. Patel
    first_name = patient_name.split()[0] if patient_name else "there"
    doctor_prompt = (
        f"Hello {first_name}, this is Dr. Patel following up on your message: "
        f"\"{text_body[:80]}...\". How are you feeling right now?"
    )
    wa_url = f"https://wa.me/{clean_phone}?text={quote_plus(doctor_prompt)}"

    msg_id = int(time.time() * 1000)
    snippet = f"Patient asked: \"{text_body}\""
    if vitals_str:
        snippet += f" | 🩺 Recorded: {vitals_str}"

    escalation_msg = {
        "id": msg_id,
        "type": "whatsapp",
        "sender": f"{patient_name} (via WhatsApp)",
        "patient_name": patient_name,
        "patient_id": patient_id,
        "patient_phone": sender_phone,
        "clean_phone": clean_phone,
        "subject": f"🟢 WhatsApp Consult: {patient_name} requested Dr. Patel's Advice",
        "snippet": snippet,
        "body": (
            f"CLINICAL WHATSAPP PATIENT ENCOUNTER\n\n"
            f"Patient: {patient_name} (MRN/ID: {patient_id})\n"
            f"Phone: {sender_phone}\n\n"
            f"Incoming Patient Message:\n\"{text_body}\"\n\n"
            + (f"Extracted Vital Signs:\n{vitals_str}\n\n" if vitals_str else "")
            + f"🤖 Automated Bot Status:\n"
            f"The bot replied: \"I have connected you directly to Dr. Patel. The doctor has your chart and will reply on this WhatsApp chat shortly.\"\n\n"
            f"Action Required:\nReview chart and click 'Continue Chat on WhatsApp' below to reply directly to the patient."
        ),
        "timestamp": "Just now (WhatsApp)",
        "isUnread": True,
        "status": "pending",
        "hasAttachment": False,
        "starred": True,
        "urgency": urgency,
        "vitals": vitals or {},
        "directWhatsAppUrl": wa_url,
        "doctorReplyPrompt": doctor_prompt
    }

    add_inbox_message(escalation_msg)
    print(f"[InboxManager] Added WhatsApp escalation for {patient_name} (ID: {msg_id})")
    return escalation_msg
