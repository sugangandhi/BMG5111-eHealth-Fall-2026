"""
Central Clinical EMR Cloud Integration
Connects e-Hospital platform and WhatsApp messaging engine to the centralized
AWS App Runner clinical MySQL database (77 introspected medical tables).
"""

import os
import re
import datetime
import requests
from typing import Optional, List, Dict, Any

CENTRAL_API_BASE = os.getenv(
    "CENTRAL_CLINICAL_API_URL",
    "https://aetab8pjmb.us-east-1.awsapprunner.com"
).rstrip("/")

TIMEOUT = 8


def check_central_api_health() -> Dict[str, Any]:
    """Checks live connectivity to the Central Clinical EMR Cloud."""
    try:
        resp = requests.get(f"{CENTRAL_API_BASE}/", timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json()
            return {
                "connected": True,
                "status": data.get("status", "healthy"),
                "timestamp": data.get("timestamp"),
                "tables_count": len(data.get("tables", [])),
                "endpoint": CENTRAL_API_BASE
            }
        return {"connected": False, "status": f"HTTP {resp.status_code}", "endpoint": CENTRAL_API_BASE}
    except Exception as e:
        return {"connected": False, "error": str(e), "endpoint": CENTRAL_API_BASE}


def fetch_central_patients() -> List[Dict[str, Any]]:
    """Retrieves registered patient records from the central clinical database."""
    try:
        resp = requests.get(f"{CENTRAL_API_BASE}/table/patients_registration", timeout=TIMEOUT)
        if resp.status_code == 200:
            return resp.json().get("data", [])
        return []
    except Exception as e:
        print(f"[Central EMR] Error fetching patients: {e}")
        return []


def find_central_patient(name: Optional[str] = None, phone: Optional[str] = None) -> Optional[Dict[str, Any]]:
    """
    Locates a patient record in the central EMR by either phone number or full/partial name.
    """
    patients = fetch_central_patients()
    if not patients:
        return None

    clean_phone = re.sub(r'\D', '', phone)[-10:] if phone else None

    for p in patients:
        # 1. Match by phone if provided
        if clean_phone and p.get("phone_number"):
            p_phone = re.sub(r'\D', '', str(p["phone_number"]))[-10:]
            if p_phone and p_phone == clean_phone:
                return p

        # 2. Match by contact_info if phone embedded
        if clean_phone and p.get("contact_info"):
            c_phone = re.sub(r'\D', '', str(p["contact_info"]))[-10:]
            if c_phone and c_phone == clean_phone:
                return p

        # 3. Match by name
        if name and p.get("name"):
            if name.strip().lower() in p["name"].lower() or p["name"].lower() in name.strip().lower():
                return p

    return None


def post_central_vital(
    patient_id: int,
    blood_pressure: Optional[str] = None,
    heart_rate: Optional[int] = None,
    temperature: Optional[float] = None,
    respiratory_rate: Optional[int] = None,
    notes: Optional[str] = None
) -> Dict[str, Any]:
    """
    Records newly captured patient vitals (e.g. from WhatsApp or ambient monitoring)
    directly into the Central EMR vitals_history table.
    """
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    
    payload: Dict[str, Any] = {
        "patient_id": int(patient_id),
        "recorded_on": now_iso,
        "notes": notes or "Automated clinical vitals entry via e-Hospital WhatsApp Bot"
    }

    if blood_pressure:
        payload["blood_pressure"] = str(blood_pressure).strip()
    if heart_rate:
        try:
            payload["heart_rate"] = int(heart_rate)
        except (ValueError, TypeError):
            pass
    if temperature:
        try:
            payload["temperature"] = float(temperature)
        except (ValueError, TypeError):
            pass
    if respiratory_rate:
        try:
            payload["respiratory_rate"] = int(respiratory_rate)
        except (ValueError, TypeError):
            pass

    try:
        url = f"{CENTRAL_API_BASE}/table/vitals_history"
        resp = requests.post(url, json=payload, timeout=TIMEOUT)
        if resp.status_code in [200, 201]:
            data = resp.json()
            print(f"[Central EMR] Vitals successfully written to AWS database for patient {patient_id}")
            return {"success": True, "data": data.get("data", data)}
        else:
            print(f"[Central EMR] Failed to write vitals: {resp.status_code} - {resp.text}")
            return {"success": False, "status_code": resp.status_code, "error": resp.text}
    except Exception as e:
        print(f"[Central EMR] Exception writing vitals to AWS: {e}")
        return {"success": False, "error": str(e)}


def fetch_patient_vitals_history(patient_id: int, limit: int = 20) -> List[Dict[str, Any]]:
    """Fetches historical vitals for a patient using the read-only SQL SELECT endpoint."""
    try:
        url = f"{CENTRAL_API_BASE}/sql/select"
        sql = """
            SELECT vital_id, patient_id, blood_pressure, heart_rate, temperature, respiratory_rate, recorded_on, notes
            FROM vitals_history 
            WHERE patient_id = :patient_id 
            ORDER BY recorded_on DESC 
            LIMIT :limit
        """
        payload = {
            "sql": sql,
            "replacements": {
                "patient_id": int(patient_id),
                "limit": int(limit)
            }
        }
        resp = requests.post(url, json=payload, timeout=TIMEOUT)
        if resp.status_code == 200:
            return resp.json().get("data", [])
        return []
    except Exception as e:
        print(f"[Central EMR] Error querying vitals history: {e}")
        return []


def post_patient_message_to_doctor(
    patient_id: int,
    message: str,
    doctor_id: int = 1,
    is_urgent: bool = False
) -> Dict[str, Any]:
    """
    Logs an inbound patient inquiry/WhatsApp transcript into the Central EMR
    message_pat_to_doctor table.
    """
    now_iso = datetime.datetime.now(datetime.timezone.utc).isoformat()
    payload = {
        "patient_id": int(patient_id),
        "doctor_id": int(doctor_id),
        "message": message,
        "sent_at": now_iso,
        "status": "delivered",
        "is_urgent": 1 if is_urgent else 0
    }
    try:
        url = f"{CENTRAL_API_BASE}/table/message_pat_to_doctor"
        resp = requests.post(url, json=payload, timeout=TIMEOUT)
        if resp.status_code in [200, 201]:
            return {"success": True, "data": resp.json()}
        return {"success": False, "status_code": resp.status_code}
    except Exception as e:
        return {"success": False, "error": str(e)}


def fetch_central_appointments(limit: int = 50) -> List[Dict[str, Any]]:
    """Pulls live appointment schedules from the central clinical database."""
    try:
        url = f"{CENTRAL_API_BASE}/table/appointments"
        resp = requests.get(url, timeout=TIMEOUT)
        if resp.status_code == 200:
            data = resp.json().get("data", [])
            return data[:limit]
        return []
    except Exception as e:
        print(f"[Central EMR] Error fetching appointments: {e}")
        return []
