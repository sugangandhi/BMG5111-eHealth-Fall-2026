from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from datetime import datetime
import json
import time
import os
import re
from typing import Optional, Dict, Any, List

DB_PATH = Path(__file__).resolve().parents[1] / "data" / "clinical_records.db"

@contextmanager
def get_db():
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(DB_PATH), timeout=25.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA foreign_keys=ON;")
    try:
        yield conn
        conn.commit()
    finally:
        conn.close()

def init_db() -> None:
    """Initializes tables and indexes for real-time doctor-patient sync."""
    with get_db() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS doctor_patients (
                phone TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                clinical_notes TEXT DEFAULT '',
                doctor_id TEXT DEFAULT 'Dr. Sugan',
                status TEXT DEFAULT 'Active',
                created_at TEXT NOT NULL,
                last_active TEXT NOT NULL,
                unread_count INTEGER DEFAULT 0
            );
        """)

        conn.execute("""
            CREATE TABLE IF NOT EXISTS patient_chat_messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                message_id TEXT UNIQUE,
                patient_phone TEXT NOT NULL,
                sender_role TEXT NOT NULL,   -- 'doctor', 'patient', 'bot', 'system'
                sender_name TEXT NOT NULL,
                channel TEXT DEFAULT 'whatsapp',
                text TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                status TEXT DEFAULT 'sent',  -- 'sent', 'delivered', 'read'
                vitals_json TEXT DEFAULT '{}',
                is_voice INTEGER DEFAULT 0,
                audio_url TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                FOREIGN KEY (patient_phone) REFERENCES doctor_patients(phone) ON DELETE CASCADE
            );
        """)

        conn.execute("CREATE INDEX IF NOT EXISTS idx_messages_phone ON patient_chat_messages(patient_phone);")
        conn.execute("CREATE INDEX IF NOT EXISTS idx_messages_created ON patient_chat_messages(created_at);")

def clean_phone_number(phone: str) -> str:
    """Standardizes phone numbers to pure digits."""
    return re.sub(r'\D', '', phone or '').strip()

def get_patients() -> list[dict[str, Any]]:
    """Retrieves all patients ordered by most recent activity."""
    init_db()
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT phone, name, clinical_notes, doctor_id, status, created_at, last_active, unread_count
            FROM doctor_patients
            ORDER BY datetime(last_active) DESC;
        """)
        rows = cursor.fetchall()
        return [
            {
                "patient_id": row["phone"],
                "name": row["name"],
                "phone": row["phone"],
                "condition": row["clinical_notes"],
                "doctor_id": row["doctor_id"],
                "status": row["status"],
                "created_at": row["created_at"],
                "last_active": row["last_active"],
                "unread_count": row["unread_count"],
            }
            for row in rows
        ]

def get_patient(phone: str) -> Optional[Dict[str, Any]]:
    """Retrieves a single patient by phone."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        return None
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT phone, name, clinical_notes, doctor_id, status, created_at, last_active, unread_count
            FROM doctor_patients
            WHERE phone = ? OR phone LIKE ?;
        """, (clean_p, f"%{clean_p[-10:]}"))
        row = cursor.fetchone()
        if row:
            return {
                "patient_id": row["phone"],
                "name": row["name"],
                "phone": row["phone"],
                "condition": row["clinical_notes"],
                "doctor_id": row["doctor_id"],
                "status": row["status"],
                "created_at": row["created_at"],
                "last_active": row["last_active"],
                "unread_count": row["unread_count"],
            }
        return None

def upsert_patient(
    phone: str,
    name: str,
    clinical_notes: str = "",
    doctor_id: str = "Dr. Sugan",
    status: str = "Active",
) -> Dict[str, Any]:
    """Adds or updates a patient contact in the database."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        raise ValueError("Invalid phone number provided")
    
    clean_name = name.strip() or f"Patient {clean_p[-4:]}"
    now_iso = datetime.utcnow().isoformat() + "Z"

    with get_db() as conn:
        cursor = conn.execute("SELECT phone FROM doctor_patients WHERE phone = ?;", (clean_p,))
        existing = cursor.fetchone()
        if existing:
            conn.execute("""
                UPDATE doctor_patients
                SET name = ?, clinical_notes = COALESCE(NULLIF(?, ''), clinical_notes),
                    status = ?, last_active = ?
                WHERE phone = ?;
            """, (clean_name, clinical_notes.strip(), status, now_iso, clean_p))
        else:
            conn.execute("""
                INSERT INTO doctor_patients (phone, name, clinical_notes, doctor_id, status, created_at, last_active)
                VALUES (?, ?, ?, ?, ?, ?, ?);
            """, (clean_p, clean_name, clinical_notes.strip(), doctor_id, status, now_iso, now_iso))

    return get_patient(clean_p) or {
        "patient_id": clean_p,
        "name": clean_name,
        "phone": clean_p,
        "condition": clinical_notes,
        "status": status,
    }

def delete_patient(phone: str) -> bool:
    """Deletes a patient and cascade deletes their messages."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        return False
    with get_db() as conn:
        cursor = conn.execute("DELETE FROM doctor_patients WHERE phone = ?;", (clean_p,))
        return cursor.rowcount > 0

def get_patient_messages(phone: str) -> List[Dict[str, Any]]:
    """Retrieves all chat messages for a patient phone number."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        return []

    phone_10 = clean_p[-10:] if len(clean_p) >= 10 else clean_p
    with get_db() as conn:
        cursor = conn.execute("""
            SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                   timestamp, status, vitals_json, is_voice, audio_url, created_at
            FROM patient_chat_messages
            WHERE patient_phone = ? OR patient_phone = ? OR patient_phone LIKE ?
            ORDER BY id ASC;
        """, (clean_p, phone_10, f"%{phone_10}"))
        rows = cursor.fetchall()
        messages = []
        for row in rows:
            vitals = {}
            if row["vitals_json"]:
                try:
                    vitals = json.loads(row["vitals_json"])
                except Exception:
                    pass
            messages.append({
                "id": row["id"],
                "message_id": row["message_id"],
                "role": row["sender_role"],
                "sender_name": row["sender_name"],
                "channel": row["channel"],
                "text": row["text"],
                "timestamp": row["timestamp"],
                "status": row["status"],
                "vitals": vitals,
                "isVoice": bool(row["is_voice"]),
                "audio_url": row["audio_url"],
                "created_at": row["created_at"],
            })
        return messages

def add_chat_message(
    patient_phone: str,
    sender_role: str,
    sender_name: str,
    text: str,
    channel: str = "whatsapp",
    vitals: Optional[Dict[str, Any]] = None,
    is_voice: bool = False,
    audio_url: str = "",
    status: str = "sent",
    custom_timestamp: Optional[str] = None,
) -> Dict[str, Any]:
    """Records a message to the patient's persistent chat log in the database."""
    init_db()
    clean_p = clean_phone_number(patient_phone)
    if not clean_p:
        raise ValueError("Cannot log message without a valid patient phone number")

    # Ensure patient contact exists in DB
    existing_patient = get_patient(clean_p)
    now_iso = datetime.utcnow().isoformat() + "Z"
    if not existing_patient:
        default_name = sender_name if sender_role == "patient" else f"Patient {clean_p[-4:]}"
        upsert_patient(clean_p, name=default_name, clinical_notes="", doctor_id="Dr. Sugan")
    else:
        # Update last_active
        with get_db() as conn:
            conn.execute("UPDATE doctor_patients SET last_active = ? WHERE phone = ?;", (now_iso, clean_p))

    now_display = custom_timestamp or datetime.now().strftime("%I:%M %p")
    msg_id = f"msg_{int(time.time() * 1000)}_{sender_role[:3]}"
    vitals_str = json.dumps(vitals) if vitals else "{}"

    with get_db() as conn:
        cursor = conn.execute("""
            INSERT INTO patient_chat_messages (
                message_id, patient_phone, sender_role, sender_name, channel,
                text, timestamp, status, vitals_json, is_voice, audio_url, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            msg_id, clean_p, sender_role, sender_name, channel,
            text, now_display, status, vitals_str, 1 if is_voice else 0, audio_url, now_iso
        ))
        db_id = cursor.lastrowid

    return {
        "id": db_id,
        "message_id": msg_id,
        "role": sender_role,
        "sender_name": sender_name,
        "channel": channel,
        "text": text,
        "timestamp": now_display,
        "status": status,
        "vitals": vitals or {},
        "isVoice": is_voice,
        "audio_url": audio_url,
        "created_at": now_iso,
    }
