from __future__ import annotations

import os
import re
import time
import urllib.parse
from datetime import datetime, timezone, timedelta
from typing import Any, Dict, List, Optional

import requests

EHOSPITAL_BASE_URL = os.getenv(
    "EHOSPITAL_BASE_URL",
    "https://aetab8pjmb.us-east-1.awsapprunner.com",
).rstrip("/")

# Valid default FK IDs present in AWS eHospital doctors_registration / patients_registration / chat_table
DEFAULT_AWS_DOCTOR_ID = int(os.getenv("AWS_DEFAULT_DOCTOR_ID", "1"))
DEFAULT_AWS_PATIENT_ID = int(os.getenv("AWS_DEFAULT_PATIENT_ID", "1"))
DEFAULT_AWS_CHAT_ID = int(os.getenv("AWS_DEFAULT_CHAT_ID", "1"))

TAG_PREFIX = "maxassist:v1|"
AI_PREFIX = "[maxassist_ai|"

# Lightweight short-lived read cache so 3-second polling doesn't spam AWS
_CACHE: Dict[str, tuple[float, List[Dict[str, Any]]]] = {}
_CACHE_TTL_SECONDS = 8.0


def _clean_phone(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "").strip()
    if len(digits) == 10:
        return "1" + digits
    return digits


def _phone_key10(phone: str) -> str:
    digits = re.sub(r"\D", "", phone or "").strip()
    return digits[-10:] if len(digits) >= 10 else digits


def _now_utc_iso() -> str:
    return datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S.000Z")


def _encode_meta(
    owner_id: str,
    phone: str,
    name: str,
    is_voice: bool = False,
    msg_id: str = "",
) -> str:
    safe_owner = urllib.parse.quote((owner_id or "").strip()[:64], safe="@._-")
    safe_phone = _clean_phone(phone)[:20]
    safe_name = urllib.parse.quote((name or "").strip()[:40], safe=" ")
    safe_mid = urllib.parse.quote((msg_id or "").strip()[:48], safe="_-.")
    v = "1" if is_voice else "0"
    tag = f"{TAG_PREFIX}o={safe_owner}|p={safe_phone}|n={safe_name}|v={v}|m={safe_mid}"
    return tag[:250]


def _decode_meta(attachment_url: Any) -> Optional[Dict[str, str]]:
    if not attachment_url or not isinstance(attachment_url, str):
        return None
    if not attachment_url.startswith(TAG_PREFIX):
        return None
    body = attachment_url[len(TAG_PREFIX):]
    meta: Dict[str, str] = {}
    for part in body.split("|"):
        if "=" in part:
            k, v = part.split("=", 1)
            meta[k.strip()] = urllib.parse.unquote(v.strip())
    return meta


def _invalidate_cache(*tables: str) -> None:
    if not tables:
        _CACHE.clear()
        return
    for t in tables:
        _CACHE.pop(t, None)


def _fetch_table_rows(table_name: str, force_refresh: bool = False) -> List[Dict[str, Any]]:
    now = time.time()
    if not force_refresh and table_name in _CACHE:
        ts, cached = _CACHE[table_name]
        if now - ts < _CACHE_TTL_SECONDS:
            return cached
    try:
        resp = requests.get(
            f"{EHOSPITAL_BASE_URL}/table/{table_name}",
            timeout=7,
            verify=False,
        )
        if resp.status_code == 200:
            payload = resp.json()
            rows = payload.get("data", []) if isinstance(payload, dict) else []
            if isinstance(rows, list):
                _CACHE[table_name] = (now, rows)
                return rows
    except Exception as exc:
        print(f"[AWS Chat Store] GET /table/{table_name} error: {exc}")
    # Return stale cache if available
    if table_name in _CACHE:
        return _CACHE[table_name][1]
    return []


def save_contact_to_aws(
    owner_id: str,
    patient_phone: str,
    patient_name: str,
    notes: str = "",
) -> bool:
    """Persists a contact marker into AWS message_doctor_to_pat so contacts survive restarts/reinstalls."""
    clean_owner = (owner_id or "").strip()
    clean_p = _clean_phone(patient_phone)
    if not clean_owner or len(clean_p) < 10:
        return False

    # Avoid duplicate contact markers for same owner + phone
    existing = fetch_contacts_from_aws(clean_owner)
    key10 = _phone_key10(clean_p)
    if any(_phone_key10(c.get("phone", "")) == key10 for c in existing):
        return True

    payload = {
        "doctor_id": DEFAULT_AWS_DOCTOR_ID,
        "patient_id": DEFAULT_AWS_PATIENT_ID,
        "message": (notes or f"Contact saved: {patient_name}")[:200],
        "sent_at": _now_utc_iso(),
        "status": "contact_meta",
        "is_urgent": False,
        "attachment_url": _encode_meta(
            owner_id=clean_owner,
            phone=clean_p,
            name=patient_name or f"Patient {key10[-4:]}",
            is_voice=False,
            msg_id=f"contact_{key10}",
        ),
    }
    try:
        resp = requests.post(
            f"{EHOSPITAL_BASE_URL}/table/message_doctor_to_pat",
            json=payload,
            timeout=7,
            verify=False,
        )
        if resp.status_code in (200, 201):
            _invalidate_cache("message_doctor_to_pat")
            return True
        print(f"[AWS Chat Store] save_contact failed ({resp.status_code}): {resp.text[:160]}")
    except Exception as exc:
        print(f"[AWS Chat Store] save_contact error: {exc}")
    return False


def save_message_to_aws(
    sender_role: str,
    patient_phone: str,
    text: str,
    owner_id: str = "",
    patient_name: str = "",
    is_voice: bool = False,
    status: str = "delivered",
    msg_id: str = "",
    sent_at_iso: Optional[str] = None,
) -> bool:
    """
    Writes a 1-on-1 chat message permanently to AWS:
      - doctor / bot -> message_doctor_to_pat
      - patient / user -> message_pat_to_doctor
    """
    clean_p = _clean_phone(patient_phone)
    clean_text = (text or "").strip()
    if len(clean_p) < 10 or not clean_text:
        return False

    role = (sender_role or "doctor").lower()
    is_inbound = role in ("patient", "user")
    table = "message_pat_to_doctor" if is_inbound else "message_doctor_to_pat"
    now_iso = sent_at_iso or _now_utc_iso()

    # Idempotency check: prevent duplicate AWS rows if user taps Save more than once
    clean_owner = (owner_id or "").strip()
    key10 = _phone_key10(clean_p)
    norm_new = re.sub(r"[\s\*\_]+", " ", clean_text).strip().lower()
    existing_rows = _fetch_table_rows(table, force_refresh=True)
    for er in existing_rows:
        if str(er.get("status") or "") == "contact_meta":
            continue
        em = _decode_meta(er.get("attachment_url"))
        if not em:
            continue
        if clean_owner and (em.get("o") or "").strip() != clean_owner:
            continue
        if _phone_key10(em.get("p", "")) != key10:
            continue
        er_mid = (em.get("m") or "").strip()
        er_norm = re.sub(r"[\s\*\_]+", " ", str(er.get("message") or "")).strip().lower()
        if (msg_id and er_mid == msg_id) or (norm_new and er_norm == norm_new):
            return True

    payload = {
        "doctor_id": DEFAULT_AWS_DOCTOR_ID,
        "patient_id": DEFAULT_AWS_PATIENT_ID,
        "message": clean_text[:2000],
        "sent_at": now_iso,
        "status": status or "delivered",
        "is_urgent": False,
        "attachment_url": _encode_meta(
            owner_id=owner_id,
            phone=clean_p,
            name=patient_name or f"Patient {clean_p[-4:]}",
            is_voice=is_voice,
            msg_id=msg_id,
        ),
    }
    try:
        resp = requests.post(
            f"{EHOSPITAL_BASE_URL}/table/{table}",
            json=payload,
            timeout=7,
            verify=False,
        )
        if resp.status_code in (200, 201):
            _invalidate_cache(table)
            return True
        print(f"[AWS Chat Store] POST {table} failed ({resp.status_code}): {resp.text[:160]}")
    except Exception as exc:
        print(f"[AWS Chat Store] POST {table} error: {exc}")
    return False


def fetch_contacts_from_aws(owner_id: str) -> List[Dict[str, Any]]:
    """Reconstructs a user's saved contacts list from AWS message_doctor_to_pat."""
    clean_owner = (owner_id or "").strip()
    if not clean_owner:
        return []

    rows = _fetch_table_rows("message_doctor_to_pat")
    by_phone10: Dict[str, Dict[str, Any]] = {}
    for row in rows:
        meta = _decode_meta(row.get("attachment_url"))
        if not meta:
            continue
        if (meta.get("o") or "").strip() != clean_owner:
            continue
        phone = _clean_phone(meta.get("p") or "")
        if len(phone) < 10:
            continue
        key10 = _phone_key10(phone)
        name = (meta.get("n") or "").strip() or f"Patient {key10[-4:]}"
        sent_at = str(row.get("sent_at") or "")
        existing = by_phone10.get(key10)
        if existing is None:
            by_phone10[key10] = {
                "patient_id": phone,
                "phone": phone,
                "name": name,
                "condition": "",
                "owner_id": clean_owner,
                "last_active": sent_at,
            }
        else:
            # Prefer non-placeholder name and latest timestamp
            if not name.startswith("Patient ") and existing["name"].startswith("Patient "):
                existing["name"] = name
            if sent_at > existing["last_active"]:
                existing["last_active"] = sent_at

    contacts = list(by_phone10.values())
    contacts.sort(key=lambda c: c.get("last_active", ""), reverse=True)
    return contacts


def fetch_contact_messages_from_aws(
    patient_phone: str,
    owner_id: str = "",
) -> List[Dict[str, Any]]:
    """Fetches and merges doctor + patient messages from AWS for one contact, scoped to owner_id."""
    target10 = _phone_key10(patient_phone)
    if len(target10) < 10:
        return []

    clean_owner = (owner_id or "").strip()
    doc_rows = _fetch_table_rows("message_doctor_to_pat")
    pat_rows = _fetch_table_rows("message_pat_to_doctor")

    # Determine whether this owner owns/interacted with this contact
    owner_has_contact = False
    if clean_owner:
        for row in doc_rows:
            meta = _decode_meta(row.get("attachment_url"))
            if meta and (meta.get("o") or "").strip() == clean_owner and _phone_key10(meta.get("p", "")) == target10:
                owner_has_contact = True
                break

    combined: List[Dict[str, Any]] = []
    seen_ids: set[str] = set()
    seen_sigs: set[tuple[str, str]] = set()

    for role_label, rows in (("doctor", doc_rows), ("patient", pat_rows)):
        for row in rows:
            if str(row.get("status") or "") == "contact_meta":
                continue
            meta = _decode_meta(row.get("attachment_url"))
            if not meta:
                continue
            if _phone_key10(meta.get("p", "")) != target10:
                continue
            row_owner = (meta.get("o") or "").strip()
            if clean_owner:
                if role_label == "doctor":
                    if row_owner != clean_owner:
                        continue
                else:
                    # Inbound WhatsApp replies have empty owner_id; include only if this owner has this contact
                    if row_owner and row_owner != clean_owner:
                        continue
                    if not row_owner and not owner_has_contact:
                        continue

            text = str(row.get("message") or "").strip()
            if not text:
                continue
            mid = (meta.get("m") or "").strip() or f"aws_{role_label}_{row.get('message_id')}"
            norm = re.sub(r"[\s\*\_]+", " ", text).strip().lower()
            sig = (role_label, norm)
            if mid in seen_ids or (norm and sig in seen_sigs):
                continue
            seen_ids.add(mid)
            if norm:
                seen_sigs.add(sig)

            created_at = str(row.get("sent_at") or _now_utc_iso())
            combined.append({
                "id": row.get("message_id"),
                "message_id": mid,
                "role": role_label,
                "sender_name": meta.get("n") or ("Doctor" if role_label == "doctor" else "Patient"),
                "channel": "whatsapp",
                "text": text,
                "status": str(row.get("status") or "delivered"),
                "isVoice": meta.get("v") == "1",
                "created_at": created_at,
                "timestamp": created_at,
            })

    combined.sort(key=lambda m: str(m.get("created_at") or ""))
    return combined


def save_ai_chat_turn_to_aws(
    owner_id: str,
    user_text: str,
    ai_reply: str,
    timestamp_iso: Optional[str] = None,
) -> bool:
    """Persists a MaxAssist AI chat Q&A turn into AWS chatbot_conversation."""
    clean_owner = (owner_id or "").strip()
    if not clean_owner or not (user_text or "").strip():
        return False

    # Idempotency check: avoid duplicate AI rows in chatbot_conversation
    msg_encoded = f"{AI_PREFIX}{clean_owner}] {user_text.strip()}"[:1800]
    resp_clean = (ai_reply or "").strip()[:1800]
    existing_ai = _fetch_table_rows("chatbot_conversation", force_refresh=True)
    for r in existing_ai:
        if str(r.get("message") or "").strip() == msg_encoded and str(r.get("response") or "").strip() == resp_clean:
            return True

    payload = {
        "chat_id": DEFAULT_AWS_CHAT_ID,
        "message": msg_encoded,
        "response": resp_clean,
        "timestamp": timestamp_iso or _now_utc_iso(),
    }
    try:
        resp = requests.post(
            f"{EHOSPITAL_BASE_URL}/table/chatbot_conversation",
            json=payload,
            timeout=7,
            verify=False,
        )
        if resp.status_code in (200, 201):
            _invalidate_cache("chatbot_conversation")
            return True
        print(f"[AWS Chat Store] POST chatbot_conversation failed ({resp.status_code}): {resp.text[:160]}")
    except Exception as exc:
        print(f"[AWS Chat Store] POST chatbot_conversation error: {exc}")
    return False


def fetch_ai_chat_history_from_aws(owner_id: str) -> List[Dict[str, Any]]:
    """Fetches a user's persistent MaxAssist AI chat history from AWS chatbot_conversation."""
    clean_owner = (owner_id or "").strip()
    if not clean_owner:
        return []

    prefix = f"{AI_PREFIX}{clean_owner}] "
    rows = _fetch_table_rows("chatbot_conversation")
    matched = [
        r for r in rows
        if isinstance(r.get("message"), str) and r["message"].startswith(prefix)
    ]
    matched.sort(key=lambda r: (str(r.get("timestamp") or ""), int(r.get("conversation_id") or 0)))

    messages: List[Dict[str, Any]] = []
    for r in matched:
        ts = str(r.get("timestamp") or _now_utc_iso())
        cid = r.get("conversation_id")
        user_msg = r["message"][len(prefix):].strip()
        ai_resp = str(r.get("response") or "").strip()
        if user_msg:
            messages.append({
                "id": f"aws_ai_u_{cid}",
                "role": "doctor",
                "text": user_msg,
                "status": "delivered",
                "timestamp": ts,
            })
        if ai_resp:
            messages.append({
                "id": f"aws_ai_a_{cid}",
                "role": "assistant",
                "text": ai_resp,
                "status": "delivered",
                "timestamp": ts,
            })
    return messages


def delete_message_from_aws(
    owner_id: str,
    text: str,
    patient_phone: str = "",
    role: str = "doctor",
    msg_id: str = "",
    is_ai_chat: bool = False,
) -> bool:
    """Deletes a previously saved message from AWS when the user toggles Undo Save."""
    clean_owner = (owner_id or "").strip()
    clean_text = (text or "").strip()
    if not clean_text:
        return False

    if is_ai_chat:
        rows = _fetch_table_rows("chatbot_conversation", force_refresh=True)
        prefix = f"{AI_PREFIX}{clean_owner or 'maxassist_user'}] "
        deleted_any = False
        for r in rows:
            cid = r.get("conversation_id")
            m_str = str(r.get("message") or "")
            resp_str = str(r.get("response") or "")
            if not m_str.startswith(prefix):
                continue
            body = m_str[len(prefix):].strip()
            if body == clean_text or resp_str.strip() == clean_text:
                try:
                    dr = requests.delete(
                        f"{EHOSPITAL_BASE_URL}/table/chatbot_conversation/{cid}",
                        timeout=7,
                        verify=False,
                    )
                    if dr.status_code in (200, 204):
                        deleted_any = True
                except Exception:
                    pass
        if deleted_any:
            _invalidate_cache("chatbot_conversation")
        return True

    target10 = _phone_key10(patient_phone)
    is_inbound = (role or "doctor").lower() in ("patient", "user")
    table = "message_pat_to_doctor" if is_inbound else "message_doctor_to_pat"
    rows = _fetch_table_rows(table, force_refresh=True)
    deleted_any = False
    for r in rows:
        if str(r.get("status") or "") == "contact_meta":
            continue
        meta = _decode_meta(r.get("attachment_url"))
        if not meta:
            continue
        if clean_owner and (meta.get("o") or "").strip() != clean_owner:
            continue
        if target10 and _phone_key10(meta.get("p", "")) != target10:
            continue
        row_mid = (meta.get("m") or "").strip()
        row_text = str(r.get("message") or "").strip()
        if (msg_id and row_mid == msg_id) or row_text == clean_text:
            rid = r.get("message_id")
            if rid is not None:
                try:
                    dr = requests.delete(
                        f"{EHOSPITAL_BASE_URL}/table/{table}/{rid}",
                        timeout=7,
                        verify=False,
                    )
                    if dr.status_code in (200, 204):
                        deleted_any = True
                except Exception:
                    pass
    if deleted_any:
        _invalidate_cache(table)
    return True

