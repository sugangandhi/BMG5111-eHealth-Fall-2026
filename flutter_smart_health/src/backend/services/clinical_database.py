from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from pathlib import Path
from datetime import datetime, timezone, timedelta
try:
    from zoneinfo import ZoneInfo
except ImportError:
    ZoneInfo = None  # type: ignore

def _now_ontario() -> datetime:
    """Returns current Ontario (America/Toronto) local time with automatic EST/EDT handling."""
    if ZoneInfo is not None:
        try:
            return datetime.now(ZoneInfo("America/Toronto"))
        except Exception:
            pass
    return datetime.now(timezone(timedelta(hours=-5)))
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

        conn.execute("""
            CREATE TABLE IF NOT EXISTS doctor_whatsapp_config (
                doctor_id TEXT PRIMARY KEY,
                whatsapp_phone TEXT NOT NULL,
                verified INTEGER DEFAULT 1,
                verified_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
        """)

        conn.execute("""
            CREATE TABLE IF NOT EXISTS scheduled_tasks (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doctor_id TEXT NOT NULL,
                patient_phone TEXT NOT NULL,
                patient_name TEXT NOT NULL,
                message_text TEXT NOT NULL,
                scheduled_for_utc TEXT NOT NULL,
                scheduled_display TEXT NOT NULL,
                status TEXT DEFAULT 'pending',
                created_at TEXT NOT NULL,
                sent_at TEXT DEFAULT '',
                error_note TEXT DEFAULT ''
            );
        """)
        conn.execute("CREATE INDEX IF NOT EXISTS idx_scheduled_status_time ON scheduled_tasks(status, scheduled_for_utc);")

        # Safe additive migrations for per-device owner_id isolation
        for tbl in ("doctor_patients", "patient_chat_messages", "scheduled_tasks"):
            cols = {r[1] for r in conn.execute(f"PRAGMA table_info({tbl});").fetchall()}
            if "owner_id" not in cols:
                conn.execute(f"ALTER TABLE {tbl} ADD COLUMN owner_id TEXT DEFAULT '';")

def clean_phone_number(phone: str) -> str:
    """Standardizes phone numbers to pure digits."""
    return re.sub(r'\D', '', phone or '').strip()

def get_patients(owner_id: Optional[str] = None) -> list[dict[str, Any]]:
    """Retrieves patients ordered by most recent activity, strictly scoped by owner_id when provided."""
    init_db()
    with get_db() as conn:
        if owner_id is not None and owner_id.strip():
            cursor = conn.execute("""
                SELECT phone, name, clinical_notes, doctor_id, status, created_at, last_active, unread_count, owner_id
                FROM doctor_patients
                WHERE owner_id = ?
                ORDER BY datetime(last_active) DESC;
            """, (owner_id.strip(),))
        else:
            cursor = conn.execute("""
                SELECT phone, name, clinical_notes, doctor_id, status, created_at, last_active, unread_count, owner_id
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
                "owner_id": row["owner_id"],
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
    owner_id: str = "",
) -> Dict[str, Any]:
    """Adds or updates a patient contact in the database."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        raise ValueError("Invalid phone number provided")
    
    clean_name = name.strip() or f"Patient {clean_p[-4:]}"
    clean_owner = (owner_id or "").strip()
    now_iso = datetime.utcnow().isoformat() + "Z"

    with get_db() as conn:
        cursor = conn.execute("SELECT phone FROM doctor_patients WHERE phone = ?;", (clean_p,))
        existing = cursor.fetchone()
        if existing:
            conn.execute("""
                UPDATE doctor_patients
                SET name = ?, clinical_notes = COALESCE(NULLIF(?, ''), clinical_notes),
                    doctor_id = COALESCE(NULLIF(?, ''), doctor_id),
                    owner_id = CASE WHEN ? != '' THEN ? ELSE owner_id END,
                    status = ?, last_active = ?
                WHERE phone = ?;
            """, (clean_name, clinical_notes.strip(), doctor_id, clean_owner, clean_owner, status, now_iso, clean_p))
        else:
            conn.execute("""
                INSERT INTO doctor_patients (phone, name, clinical_notes, doctor_id, status, created_at, last_active, owner_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """, (clean_p, clean_name, clinical_notes.strip(), doctor_id, status, now_iso, now_iso, clean_owner))

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

def is_message_processed(msg_id: str) -> bool:
    """Checks if a message ID has already been recorded in patient_chat_messages."""
    if not msg_id:
        return False
    init_db()
    with get_db() as conn:
        cursor = conn.execute("SELECT 1 FROM patient_chat_messages WHERE message_id = ? LIMIT 1;", (str(msg_id),))
        return cursor.fetchone() is not None

def get_patient_messages(phone: str, owner_id: Optional[str] = None) -> List[Dict[str, Any]]:
    """Retrieves chat messages for a patient phone number, deduplicated and isolated by owner_id when provided."""
    init_db()
    clean_p = clean_phone_number(phone)
    if not clean_p:
        return []

    phone_10 = clean_p[-10:] if len(clean_p) >= 10 else clean_p
    clean_owner = (owner_id or "").strip()
    with get_db() as conn:
        if clean_owner:
            # Verify this device owns this patient contact before including shared inbound WhatsApp replies
            owns_patient = conn.execute(
                "SELECT 1 FROM doctor_patients WHERE (phone = ? OR phone = ? OR phone LIKE ?) AND owner_id = ? LIMIT 1;",
                (clean_p, phone_10, f"%{phone_10}", clean_owner),
            ).fetchone() is not None

            if owns_patient:
                cursor = conn.execute("""
                    SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                           timestamp, status, vitals_json, is_voice, audio_url, created_at
                    FROM patient_chat_messages
                    WHERE (patient_phone = ? OR patient_phone = ? OR patient_phone LIKE ?)
                      AND (owner_id = ? OR (owner_id = '' AND sender_role = 'patient'))
                    ORDER BY id ASC;
                """, (clean_p, phone_10, f"%{phone_10}", clean_owner))
            else:
                cursor = conn.execute("""
                    SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                           timestamp, status, vitals_json, is_voice, audio_url, created_at
                    FROM patient_chat_messages
                    WHERE (patient_phone = ? OR patient_phone = ? OR patient_phone LIKE ?)
                      AND owner_id = ?
                    ORDER BY id ASC;
                """, (clean_p, phone_10, f"%{phone_10}", clean_owner))
        else:
            cursor = conn.execute("""
                SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                       timestamp, status, vitals_json, is_voice, audio_url, created_at
                FROM patient_chat_messages
                WHERE patient_phone = ? OR patient_phone = ? OR patient_phone LIKE ?
                ORDER BY id ASC;
            """, (clean_p, phone_10, f"%{phone_10}"))
        rows = cursor.fetchall()
        messages = []
        seen_msg_ids = set()
        seen_text_signatures = set()
        for row in rows:
            mid = row["message_id"] or str(row["id"])
            if mid and mid in seen_msg_ids:
                continue
            if mid:
                seen_msg_ids.add(mid)

            # Deduplicate identical message signatures to prevent webhook retry clutter
            norm_content = re.sub(r'[\s\*\_]+', ' ', (row["text"] or "")).strip().lower()
            sig = (row["sender_role"], norm_content)
            if norm_content and sig in seen_text_signatures:
                continue
            if norm_content:
                seen_text_signatures.add(sig)

            vitals = {}
            if row["vitals_json"]:
                try:
                    vitals = json.loads(row["vitals_json"])
                except Exception:
                    pass
            messages.append({
                "id": row["id"],
                "message_id": row["message_id"] or str(row["id"]),
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
    custom_msg_id: Optional[str] = None,
    owner_id: str = "",
) -> Dict[str, Any]:
    """Records a message to the patient's persistent chat log in the database."""
    init_db()
    clean_p = clean_phone_number(patient_phone)
    if not clean_p:
        raise ValueError("Cannot log message without a valid patient phone number")

    # If custom_msg_id provided and already processed, return existing message immediately
    if custom_msg_id:
        with get_db() as conn:
            cursor = conn.execute("""
                SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                       timestamp, status, vitals_json, is_voice, audio_url, created_at
                FROM patient_chat_messages
                WHERE message_id = ? LIMIT 1;
            """, (str(custom_msg_id),))
            existing_row = cursor.fetchone()
            if existing_row:
                evitals = {}
                if existing_row["vitals_json"]:
                    try:
                        evitals = json.loads(existing_row["vitals_json"])
                    except Exception:
                        pass
                return {
                    "id": existing_row["id"],
                    "message_id": existing_row["message_id"],
                    "role": existing_row["sender_role"],
                    "sender_name": existing_row["sender_name"],
                    "channel": existing_row["channel"],
                    "text": existing_row["text"],
                    "timestamp": existing_row["timestamp"],
                    "status": existing_row["status"],
                    "vitals": evitals,
                    "isVoice": bool(existing_row["is_voice"]),
                    "audio_url": existing_row["audio_url"],
                    "created_at": existing_row["created_at"],
                }

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

    now_display = custom_timestamp or _now_ontario().strftime("%I:%M %p").lstrip("0")
    msg_id = custom_msg_id or f"msg_{int(time.time() * 1000)}_{sender_role[:3]}"
    vitals_str = json.dumps(vitals) if vitals else "{}"

    with get_db() as conn:
        cursor = conn.execute("""
            INSERT OR IGNORE INTO patient_chat_messages (
                message_id, patient_phone, sender_role, sender_name, channel,
                text, timestamp, status, vitals_json, is_voice, audio_url, created_at, owner_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """, (
            msg_id, clean_p, sender_role, sender_name, channel,
            text, now_display, status, vitals_str, 1 if is_voice else 0, audio_url, now_iso, (owner_id or "").strip()
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

def get_doctor_whatsapp_config(doctor_id: str = "Dr. Sugan") -> Optional[Dict[str, Any]]:
    """Retrieves the doctor's verified WhatsApp agent number from persistent storage."""
    init_db()
    doc_key = (doctor_id or "Dr. Sugan").strip()
    with get_db() as conn:
        cursor = conn.execute(
            """
            SELECT doctor_id, whatsapp_phone, verified, verified_at, updated_at
            FROM doctor_whatsapp_config
            WHERE doctor_id = ? LIMIT 1;
            """,
            (doc_key,),
        )
        row = cursor.fetchone()
        if not row:
            cursor = conn.execute(
                """
                SELECT doctor_id, whatsapp_phone, verified, verified_at, updated_at
                FROM doctor_whatsapp_config
                ORDER BY datetime(updated_at) DESC LIMIT 1;
                """
            )
            row = cursor.fetchone()
        if row:
            return {
                "doctor_id": row["doctor_id"],
                "whatsapp_phone": row["whatsapp_phone"],
                "verified": bool(row["verified"]),
                "verified_at": row["verified_at"],
                "updated_at": row["updated_at"],
            }
        return None


def upsert_doctor_whatsapp_config(
    whatsapp_phone: str,
    doctor_id: str = "Dr. Sugan",
) -> Dict[str, Any]:
    """Saves or updates the doctor's verified WhatsApp agent number permanently."""
    init_db()
    clean_p = clean_phone_number(whatsapp_phone)
    if len(clean_p) == 10:
        clean_p = "1" + clean_p
    if len(clean_p) < 10:
        raise ValueError("Invalid WhatsApp phone number")

    doc_key = (doctor_id or "Dr. Sugan").strip()
    now_iso = datetime.utcnow().isoformat() + "Z"
    with get_db() as conn:
        conn.execute(
            """
            INSERT INTO doctor_whatsapp_config (doctor_id, whatsapp_phone, verified, verified_at, updated_at)
            VALUES (?, ?, 1, ?, ?)
            ON CONFLICT(doctor_id) DO UPDATE SET
                whatsapp_phone = excluded.whatsapp_phone,
                verified = 1,
                verified_at = excluded.verified_at,
                updated_at = excluded.updated_at;
            """,
            (doc_key, clean_p, now_iso, now_iso),
        )
    return {
        "doctor_id": doc_key,
        "whatsapp_phone": clean_p,
        "verified": True,
        "verified_at": now_iso,
        "updated_at": now_iso,
    }


def create_scheduled_task(
    doctor_id: str,
    patient_phone: str,
    patient_name: str,
    message_text: str,
    scheduled_for_utc: str,
    scheduled_display: str = "",
    owner_id: str = "",
) -> Dict[str, Any]:
    """Creates a persistent scheduled WhatsApp task in SQLite."""
    init_db()
    clean_p = clean_phone_number(patient_phone)
    if len(clean_p) == 10:
        clean_p = "1" + clean_p
    if len(clean_p) < 10:
        raise ValueError("Invalid patient phone number for scheduled task")

    now_iso = datetime.utcnow().isoformat() + "Z"
    doc = (doctor_id or "Dr. Sugan").strip()
    p_name = (patient_name or f"Patient {clean_p[-4:]}").strip()
    display = scheduled_display.strip() or scheduled_for_utc
    clean_owner = (owner_id or "").strip()

    with get_db() as conn:
        cursor = conn.execute(
            """
            INSERT INTO scheduled_tasks (
                doctor_id, patient_phone, patient_name, message_text,
                scheduled_for_utc, scheduled_display, status, created_at, owner_id
            ) VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?);
            """,
            (doc, clean_p, p_name, message_text.strip(), scheduled_for_utc, display, now_iso, clean_owner),
        )
        task_id = cursor.lastrowid

    return {
        "id": task_id,
        "doctor_id": doc,
        "owner_id": clean_owner,
        "patient_phone": clean_p,
        "patient_name": p_name,
        "message_text": message_text.strip(),
        "scheduled_for_utc": scheduled_for_utc,
        "scheduled_display": display,
        "status": "pending",
        "created_at": now_iso,
        "sent_at": "",
        "error_note": "",
    }


def list_scheduled_tasks(
    status: Optional[str] = None,
    patient_phone: Optional[str] = None,
    owner_id: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """Lists scheduled tasks ordered by soonest first, scoped by owner_id when provided."""
    init_db()
    query = "SELECT * FROM scheduled_tasks WHERE 1=1"
    params: list[Any] = []
    if owner_id is not None and owner_id.strip():
        query += " AND owner_id = ?"
        params.append(owner_id.strip())
    if status:
        query += " AND status = ?"
        params.append(status)
    if patient_phone:
        clean_p = clean_phone_number(patient_phone)
        if clean_p:
            query += " AND (patient_phone = ? OR patient_phone LIKE ?)"
            params.extend([clean_p, f"%{clean_p[-10:]}"])
    query += " ORDER BY CASE WHEN status = 'pending' THEN 0 ELSE 1 END, scheduled_for_utc ASC, id DESC LIMIT 100;"
    with get_db() as conn:
        rows = conn.execute(query, params).fetchall()
        return [dict(r) for r in rows]


def cancel_scheduled_task(task_id: int) -> bool:
    """Marks a pending scheduled task as cancelled."""
    init_db()
    with get_db() as conn:
        cursor = conn.execute(
            "UPDATE scheduled_tasks SET status = 'cancelled' WHERE id = ? AND status = 'pending';",
            (int(task_id),),
        )
        return cursor.rowcount > 0


def get_due_scheduled_tasks(now_utc_iso: Optional[str] = None) -> List[Dict[str, Any]]:
    """Returns all pending scheduled tasks whose scheduled_for_utc <= now."""
    init_db()
    cutoff = now_utc_iso or (datetime.utcnow().isoformat() + "Z")
    with get_db() as conn:
        rows = conn.execute(
            """
            SELECT * FROM scheduled_tasks
            WHERE status = 'pending' AND scheduled_for_utc <= ?
            ORDER BY scheduled_for_utc ASC;
            """,
            (cutoff,),
        ).fetchall()
        return [dict(r) for r in rows]


def mark_scheduled_task_sent(task_id: int) -> None:
    init_db()
    now_iso = datetime.utcnow().isoformat() + "Z"
    with get_db() as conn:
        conn.execute(
            "UPDATE scheduled_tasks SET status = 'sent', sent_at = ?, error_note = '' WHERE id = ?;",
            (now_iso, int(task_id)),
        )


def mark_scheduled_task_failed(task_id: int, error_note: str) -> None:
    init_db()
    with get_db() as conn:
        conn.execute(
            "UPDATE scheduled_tasks SET status = 'failed', error_note = ? WHERE id = ?;",
            (str(error_note)[:500], int(task_id)),
        )


def get_database_dump() -> Dict[str, Any]:
    """Returns a full inspection dump of the clinical database for monitoring and verification."""
    init_db()
    with get_db() as conn:
        cursor_p = conn.execute("""
            SELECT phone, name, clinical_notes, doctor_id, status, created_at, last_active, unread_count
            FROM doctor_patients
            ORDER BY datetime(last_active) DESC;
        """)
        patients = [dict(r) for r in cursor_p.fetchall()]

        cursor_m = conn.execute("""
            SELECT id, message_id, patient_phone, sender_role, sender_name, channel, text,
                   timestamp, status, vitals_json, is_voice, audio_url, created_at
            FROM patient_chat_messages
            ORDER BY id DESC LIMIT 200;
        """)
        messages = [dict(r) for r in cursor_m.fetchall()]

        cursor_c = conn.execute("""
            SELECT doctor_id, whatsapp_phone, verified, verified_at, updated_at
            FROM doctor_whatsapp_config;
        """)
        wa_configs = [dict(r) for r in cursor_c.fetchall()]

        cursor_t = conn.execute("""
            SELECT * FROM scheduled_tasks ORDER BY id DESC LIMIT 100;
        """)
        tasks = [dict(r) for r in cursor_t.fetchall()]

        return {
            "db_path": str(DB_PATH),
            "total_patients": len(patients),
            "total_messages": len(messages),
            "total_scheduled_tasks": len(tasks),
            "doctor_whatsapp_configs": wa_configs,
            "scheduled_tasks": tasks,
            "patients": patients,
            "messages": messages,
        }
