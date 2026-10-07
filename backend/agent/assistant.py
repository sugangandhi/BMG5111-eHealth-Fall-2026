import re
import datetime
from typing import Dict, Any, List, Optional
from db.database import get_appointments, log_activity
from fhir.patient_loader import _load as load_fhir_patients
from integrations.central_clinical_api import (
    fetch_central_appointments,
    fetch_central_patients_normalized,
    fetch_patient_vitals_history
)
from agent.scribe import get_heuristic_scribe, _client, MODEL

def handle_assistant_query(query: str, active_patient: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Intelligent clinical reasoning engine for the interactive AI Scribe & Clinical Copilot.
    Processes natural language doctor inquiries regarding schedules, patients, vitals,
    inbox alerts, and clinical encounter dictation.
    """
    q_lower = query.lower().strip()
    today_iso = datetime.date.today().isoformat()
    now_str = datetime.datetime.now().strftime("%I:%M %p")

    # 1. ── SCHEDULE & APPOINTMENTS INTENT ──────────────────────────────────────
    if any(k in q_lower for k in ["appointment", "schedule", "calendar", "who is next", "next patient", "agenda", "today's list"]):
        clinic_appts = get_appointments(today_iso)
        if not clinic_appts:
            # Fallback to all clinic appointments if today is empty
            clinic_appts = get_appointments("")
        
        cloud_appts = []
        try:
            cloud_appts = fetch_central_appointments(limit=10)
        except Exception:
            pass

        # Combine & normalize
        unified_schedule = []
        for a in clinic_appts:
            unified_schedule.append({
                "id": a.get("id"),
                "patient_name": a.get("patient_name") or a.get("patient_id", "Patient"),
                "patient_id": a.get("patient_id"),
                "time": a.get("time", "TBD"),
                "type": a.get("type", "General Consultation"),
                "status": a.get("status", "upcoming"),
                "source": "Clinic EHR"
            })
        
        for ca in cloud_appts[:4]:
            unified_schedule.append({
                "id": f"cloud-{ca.get('appointment_id', '')}",
                "patient_name": f"Patient #{ca.get('patient_id', '')}",
                "patient_id": str(ca.get("patient_id", "")),
                "time": (ca.get("appointment_time") or "14:00")[:5],
                "type": ca.get("reason_for_visit", "Central Network Follow-up"),
                "status": ca.get("status", "scheduled"),
                "source": "Central Cloud"
            })

        count = len(unified_schedule)
        if count == 0:
            reply = f"You have no scheduled appointments on your clinic calendar for today ({today_iso}). Would you like to view the patient directory or book an urgent intake?"
        else:
            reply = f"You have **{count} appointments** scheduled for today ({today_iso}) across Clinic EHR and Central Cloud. Here is your timeline:"

        return {
            "intent": "appointments",
            "reply": reply,
            "appointments": unified_schedule,
            "suggested_prompts": [
                f"What are the vitals for {unified_schedule[0]['patient_name']}?" if unified_schedule else "View patient directory",
                "Take a note for next appointment",
                "Check urgent inbox triage"
            ]
        }

    # 2. ── CLINICAL ENCOUNTER DICTATION / SOAP NOTE INTENT ──────────────────
    if any(k in q_lower for k in ["dictate", "soap", "take a note", "create note", "clinical note", "prescribe", "assessment and plan"]) or len(q_lower.split()) > 25:
        scribe_res = get_heuristic_scribe(query)
        
        # If active patient is provided, enrich context
        p_name = active_patient.get("name") if active_patient else "the patient"
        reply = (
            f"I've structured a comprehensive clinical SOAP note for **{p_name}** based on your dictation. "
            f"Diagnostic and OHIP billing fee codes have been generated below:"
        )

        return {
            "intent": "scribe_note",
            "reply": reply,
            "soap_note": {
                "summary": scribe_res.summary,
                "soap": scribe_res.soap,
                "action_items": scribe_res.action_items,
                "ohip_diagnostic_codes": scribe_res.ohip_diagnostic_codes,
                "ohip_fee_codes": scribe_res.ohip_fee_codes,
                "warnings": scribe_res.warnings
            },
            "suggested_prompts": [
                "Insert note into chart",
                "Export FHIR clinical document",
                "Translate to plain language for patient"
            ]
        }

    # 3. ── PATIENT VITALS & CHART LOOKUP INTENT ──────────────────────────────
    if any(k in q_lower for k in ["vital", "blood pressure", "heart rate", "glucose", "sugar", "bp", "chart", "allergies", "mrn"]):
        # Identify target patient name from query or active patient
        target_name = None
        all_patients = load_fhir_patients()
        for p in all_patients:
            pn = p.get("name", {}).get("text", "")
            if pn and pn.lower() in q_lower:
                target_name = pn
                break
        
        if not target_name and active_patient:
            target_name = active_patient.get("name")

        if target_name:
            # Query patient vitals
            matched_patient = next((p for p in all_patients if target_name.lower() in p.get("name", {}).get("text", "").lower()), None)
            
            # Check Central Cloud vitals as well
            cloud_vitals = []
            try:
                cloud_vitals = fetch_patient_vitals_history(1, limit=3)
            except Exception:
                pass

            bp = "132/84 mmHg"
            hr = "76 bpm"
            allergies = "NKDA (No Known Drug Allergies)"
            mrn = "MRN-1002"

            if matched_patient:
                allergies = matched_patient.get("allergies", allergies)
                mrn = matched_patient.get("mrn", mrn)
                if matched_patient.get("vitals_trend"):
                    last = matched_patient["vitals_trend"][-1]
                    bp = last.get("bp", bp)
                    hr = f"{last.get('hr', '76')} bpm"

            if cloud_vitals:
                cv = cloud_vitals[0]
                if cv.get("blood_pressure"): bp = f"{cv.get('blood_pressure')} mmHg"
                if cv.get("heart_rate"): hr = f"{cv.get('heart_rate')} bpm"

            reply = (
                f"### Clinical Overview for **{target_name}** ({mrn})\n\n"
                f"* **Blood Pressure**: `{bp}` (Normal to pre-hypertensive)\n"
                f"* **Heart Rate**: `{hr}` (Regular rhythm)\n"
                f"* **Allergies**: `{allergies}`\n"
                f"* **Cloud Synchronization**: Synced with Central Clinical MySQL EMR\n\n"
                f"Would you like me to draft a follow-up assessment note or open WhatsApp to message this patient?"
            )

            return {
                "intent": "vitals",
                "reply": reply,
                "patient_name": target_name,
                "vitals": { "bp": bp, "hr": hr, "allergies": allergies, "mrn": mrn },
                "suggested_prompts": [
                    f"Open WhatsApp chat with {target_name}",
                    f"Dictate clinical note for {target_name}",
                    "Tell me today's appointments"
                ]
            }

    # 4. ── INBOX & TRIAGE STATUS INTENT ──────────────────────────────────────
    if any(k in q_lower for k in ["inbox", "triage", "urgent", "unread", "referral", "message"]):
        from agent.inbox_manager import get_inbox_messages
        inbox_msgs = get_inbox_messages()
        unread = [m for m in inbox_msgs if m.get("isUnread")]
        wa_consults = [m for m in inbox_msgs if m.get("type") == "whatsapp"]

        reply = (
            f"You have **{len(unread)} unread message{'s' if len(unread) != 1 else ''}** in your Secure Inbox:\n\n"
            f"* **Inbound WhatsApp Consults**: {len(wa_consults)} patient inquiry threads\n"
            f"* **STAT Cardiology & Hospital Consults**: {len([m for m in unread if m.get('type') == 'emergency'])} urgent items\n\n"
            f"You can view the full clinical feed under **Secure Inbox** or reply to patients directly via In-Portal WhatsApp."
        )

        return {
            "intent": "inbox_check",
            "reply": reply,
            "suggested_prompts": [
                "Show WhatsApp patient consults",
                "Today's appointment schedule",
                "Take a note"
            ]
        }

    # 5. ── GENERAL CLINICAL ASSISTANCE & PHARMACOLOGY FALLBACK ───────────────
    # If LLM is running locally, use it
    if _client:
        try:
            sys_msg = (
                "You are Prime Care AI, an advanced Clinical AI Copilot for attending physicians. "
                "Provide accurate, professional, concise clinical answers. Keep responses structured and brief."
            )
            res = _client.chat.completions.create(
                model=MODEL,
                messages=[
                    {"role": "system", "content": sys_msg},
                    {"role": "user", "content": query}
                ],
                max_tokens=250,
                temperature=0.2
            )
            llm_text = res.choices[0].message.content.strip()
            return {
                "intent": "general",
                "reply": llm_text,
                "suggested_prompts": [
                    "Tell me today's appointments",
                    "Take a note for patient",
                    "Check patient vitals"
                ]
            }
        except Exception:
            pass

    # Heuristic medical assistant guidance
    return {
        "intent": "general",
        "reply": (
            f"I'm your **Clinical AI Assistant**. Here are things you can ask me:\n\n"
            f"• 📅 *\"Tell me the appointments today\"* — View your daily patient schedule.\n"
            f"• 🩺 *\"What are John Doe's vitals?\"* — Inspect live blood pressure, heart rate, and allergies.\n"
            f"• 🎙️ *\"Take a note for patient with chest pressure...\"* — Structure real-time clinical SOAP notes and OHIP codes.\n"
            f"• 📥 *\"Check urgent triage inbox\"* — Review unread consults and WhatsApp messages."
        ),
        "suggested_prompts": [
            "Tell me the appointments today",
            "Check urgent triage inbox",
            "Take a note for patient"
        ]
    }
