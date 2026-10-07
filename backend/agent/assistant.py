import re
import datetime
import difflib
from typing import Dict, Any, List, Optional, Tuple
from db.database import (
    get_appointments,
    update_appointment_status,
    create_appointment,
    log_activity
)
from fhir.patient_loader import _load as load_fhir_patients
from integrations.central_clinical_api import (
    fetch_central_appointments,
    fetch_central_patients_normalized,
    fetch_patient_vitals_history
)
from agent.scribe import parse_dictation, get_heuristic_scribe
from agent.llm_client import generate_text_completion, get_llm_config

QUESTION_STARTERS = [
    "should i", "why", "how to", "how do i", "how can i", "can i",
    "do i", "what if", "when should", "is it", "what is", "what are",
    "tell me about", "explain", "help me decide", "review"
]

def build_clinical_system_context(active_patient: Optional[Dict[str, Any]] = None, target_patient_name: Optional[str] = None) -> str:
    """
    Constructs comprehensive real-time clinical context for the LLM Copilot,
    incorporating the EHR patient directory, active clinic roster, Ontario clinical standards,
    and current schedule state.
    """
    today_iso = datetime.date.today().isoformat()
    now_str = datetime.datetime.now().strftime("%I:%M %p")
    
    # 1. Registered Clinic Patients Roster
    pts = load_fhir_patients()
    patient_summaries = []
    for p in pts:
        pname = p.get("name", {}).get("text", "")
        pid = p.get("id", "")
        
        cond_list = []
        for c in p.get("conditions", []):
            if isinstance(c, dict):
                cond_list.append(c.get("display") or c.get("name") or str(c))
            else:
                cond_list.append(str(c))
        conds = ", ".join(cond_list) or "None documented"

        med_list = []
        for m in p.get("medications", []):
            if isinstance(m, dict):
                name = m.get("name") or m.get("display") or ""
                dose = m.get("dose") or ""
                med_list.append(f"{name} {dose}".strip())
            else:
                med_list.append(str(m))
        meds = ", ".join(med_list) or "No active prescriptions"

        allergies = p.get("allergies", "NKDA")
        patient_summaries.append(f"- {pname} ({pid}): Conditions: [{conds}]. Meds: [{meds}]. Allergies: {allergies}.")
    pts_str = "\n".join(patient_summaries)

    # 2. Active patient highlight
    active_focus = ""
    if active_patient and active_patient.get("name"):
        active_focus = f"\nACTIVE PATIENT IN FOCUS: {active_patient.get('name')} (ID: {active_patient.get('id', 'N/A')})\n"
    elif target_patient_name:
        active_focus = f"\nTARGET PATIENT IN DISCUSSION: {target_patient_name}\n"

    return f"""You are Prime Care AI, an advanced Clinical AI Copilot & Medical Reasoning Agent for attending physicians practicing in Ontario, Canada.
You possess deep medical clinical judgment, evidence-based reasoning, and complete awareness of the clinic's Electronic Health Record (EHR) database and Ontario healthcare ecosystem.

CLINICAL ENVIRONMENT CONTEXT:
- Today's Date: {today_iso} | Time: {now_str}
- Jurisdiction: Ontario, Canada (CPSO Standards of Practice, Ontario Ministry of Health, Health Canada)
{active_focus}
REGISTERED EHR CLINIC PATIENTS:
{pts_str}

ONTARIO PRACTICE & BILLING FRAMEWORK:
- OHIP Fee Schedule:
  * A007: Intermediate assessment ($33.70)
  * A001: Minor assessment ($21.70)
  * K030: Diabetes management consultation ($77.20)
  * G310: Electrocardiogram (ECG) interpretation ($11.55)
  * K045 / K046: Chronic Disease Management annual fee
- Clinical Guidelines: Diabetes Canada 2023, Canadian Cardiovascular Society (CCS), GOLD COPD, KDIGO CKD Staging.
- Clinical Forms: WSIB Form 8 (Workplace injury assessment), OESP (Ontario Energy Support Program medical confirmation), MTO (Ministry of Transportation medical fitness to drive).

CORE AGENT CAPABILITIES:
1. Deep Clinical Reasoning: Formulate differential diagnoses, diagnostic workups, pathophysiological rationale, clinical decision support (CDS), and red flags.
2. Pharmacotherapy & Therapeutics: Dosing recommendations, contraindications, drug interactions, renal (eGFR) adjustments, and adverse effect surveillance.
3. Case Analysis & Patient Management: Advise on ongoing care plans for registered clinic patients (e.g., Sarah Khan's glycemic control, David Murphy's CKD staging, Robert Chen's COPD).
4. Ontario OHIP Billing Advisory: Provide correct OHIP diagnostic and fee codes with documentation compliance rules.
5. App Workflows & Administrative Medicine: Guide the physician through clinical documentation, forms, triage, and schedule management.

Format all responses with high clinical professionalism, evidence-based clarity, and structured markdown (bullet points, bold highlights).
"""

def match_patient_appointment(query: str, appointments: List[Dict[str, Any]]) -> Optional[Dict[str, Any]]:
    """Fuzzy and token-based patient matching across schedule."""
    q_lower = query.lower()
    for a in appointments:
        p_name = (a.get("patient_name") or "").lower()
        if p_name and p_name in q_lower:
            return a

    q_tokens = [w for w in re.findall(r'\b[a-z]{3,}\b', q_lower) if w not in {
        "cancel", "today", "with", "appointment", "please", "wanna", "want", "for", "the", "tomorrow"
    }]
    best_score = 0.0
    best_match = None
    for a in appointments:
        p_name = (a.get("patient_name") or "").lower()
        p_tokens = re.findall(r'\b[a-z]{3,}\b', p_name)
        score = 0.0
        for qt in q_tokens:
            for pt in p_tokens:
                if qt == pt:
                    score += 1.0
                elif difflib.SequenceMatcher(None, qt, pt).ratio() >= 0.75:
                    score += 0.85
        if score > best_score and score >= 0.8:
            best_score = score
            best_match = a
    return best_match

def parse_time_slot(q_lower: str) -> str:
    """Extracts and normalizes appointment time into 24-hr HH:MM format."""
    m = re.search(r'\b(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b', q_lower, re.I)
    if m:
        h = int(m.group(1))
        mins = m.group(2) or '00'
        meridiem = m.group(3).lower()
        if meridiem == 'pm' and h < 12: h += 12
        elif meridiem == 'am' and h == 12: h = 0
        return f"{h:02d}:{mins}"
    m2 = re.search(r'\bat\s+(\d{1,2})(?::(\d{2}))?\b', q_lower, re.I)
    if m2:
        h = int(m2.group(1))
        mins = m2.group(2) or '00'
        if 1 <= h <= 6: h += 12
        return f"{h:02d}:{mins}"
    m3 = re.search(r'\b([01]?\d|2[0-3]):([0-5]\d)\b', q_lower)
    if m3:
        return f"{int(m3.group(1)):02d}:{m3.group(2)}"
    return "14:30"

def parse_date_slot(q_lower: str) -> str:
    """Extracts date slot from natural language, defaulting to today."""
    today = datetime.date.today()
    if "tomorrow" in q_lower:
        return (today + datetime.timedelta(days=1)).isoformat()
    if "yesterday" in q_lower:
        return (today - datetime.timedelta(days=1)).isoformat()
    m = re.search(r'\b(202\d-\d{2}-\d{2})\b', q_lower)
    if m:
        return m.group(1)
    return today.isoformat()

def extract_or_match_patient(query: str, active_patient: Optional[Dict[str, Any]] = None) -> Tuple[Optional[str], Optional[str], str]:
    """Returns (patient_name, patient_id, initials)."""
    pts = load_fhir_patients()
    q_lower = query.lower()
    for p in pts:
        pname = p.get("name", {}).get("text", "")
        if pname and pname.lower() in q_lower:
            pid = p.get("id", "pt-001")
            initials = "".join([w[0] for w in pname.split() if w]).upper()
            return pname, pid, initials

    q_tokens = [w for w in re.findall(r'\b[a-z]{3,}\b', q_lower) if w not in {
        "book", "create", "schedule", "make", "appointment", "visit", "consult",
        "intake", "today", "tomorrow", "with", "for", "please", "wanna", "want",
        "slot", "time", "clock", "hour", "mins", "need", "like"
    }]
    best_score = 0.0
    best_p = None
    for p in pts:
        pname = p.get("name", {}).get("text", "")
        p_tokens = re.findall(r'\b[a-z]{3,}\b', pname.lower())
        score = 0.0
        for qt in q_tokens:
            for pt in p_tokens:
                if qt == pt:
                    score += 1.0
                elif difflib.SequenceMatcher(None, qt, pt).ratio() >= 0.75:
                    score += 0.85
        if score > best_score and score >= 0.8:
            best_score = score
            best_p = p

    if best_p:
        pname = best_p.get("name", {}).get("text", "")
        pid = best_p.get("id", "pt-001")
        initials = "".join([w[0] for w in pname.split() if w]).upper()
        return pname, pid, initials

    if active_patient and active_patient.get("name"):
        pname = active_patient.get("name")
        pid = active_patient.get("id", "pt-ctx")
        initials = "".join([w[0] for w in pname.split() if w]).upper()
        return pname, pid, initials

    m = re.search(r'(?:for|with)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)', query)
    if m:
        pname = m.group(1).title()
        pid = f"pt-{abs(hash(pname)) % 900 + 100}"
        initials = "".join([w[0] for w in pname.split() if w]).upper()
        return pname, pid, initials

    return None, None, ""

def infer_appointment_type(q_lower: str) -> Tuple[str, str, str]:
    """Returns (appt_type, badge, color)."""
    if any(k in q_lower for k in ["diabetes", "sugar", "glucose", "metformin"]):
        return "Type 2 Diabetes follow-up", "Diabetes", "blue"
    if any(k in q_lower for k in ["copd", "lung", "breath"]):
        return "COPD management", "COPD", "orange"
    if any(k in q_lower for k in ["prenatal", "pregnancy"]):
        return "Prenatal visit — 26 weeks", "Prenatal", "pink"
    if any(k in q_lower for k in ["ckd", "kidney", "renal"]):
        return "CKD Stage 3b quarterly review", "CKD", "red"
    if any(k in q_lower for k in ["asthma", "inhaler"]):
        return "Asthma review & prescription", "Asthma", "blue"
    if any(k in q_lower for k in ["cardiac", "heart", "chest", "hypertension", "bp"]):
        return "Cardiology Consultation", "Cardio", "teal"
    if any(k in q_lower for k in ["mental", "anxiety", "depression"]):
        return "Mental health follow-up", "MH", "purple"
    if any(k in q_lower for k in ["wsib", "work", "injury"]):
        return "WSIB Form 8 assessment", "WSIB", "orange"
    return "General Consultation", "Consult", "blue"

def is_explicit_cancel_command(query: str) -> bool:
    """True ONLY if the user gives a direct imperative command to cancel."""
    q_low = query.lower().strip()
    if any(q_low.startswith(w) for w in QUESTION_STARTERS):
        return False
    return bool(
        re.search(r'\b(cancel|cancelling|delete|drop|remove)\b', q_low) and
        re.search(r'\b(appointment|visit|slot)\b', q_low)
    )

def is_explicit_book_command(query: str) -> bool:
    """True ONLY if the user gives a direct imperative command to book/create."""
    q_low = query.lower().strip()
    if any(q_low.startswith(w) for w in QUESTION_STARTERS):
        return False
    return bool(
        re.search(r'\b(book|create|schedule|make|add)\b', q_low) and
        re.search(r'\b(appointment|visit|slot|intake)\b', q_low)
    )

def is_explicit_schedule_inquiry(query: str) -> bool:
    """True ONLY if the doctor asks specifically to see today's appointments/calendar."""
    q_low = query.lower().strip()
    schedule_phrases = [
        "tell me appointments today", "show appointments", "view appointments",
        "today's appointments", "my appointments today", "what appointments today",
        "show schedule", "view schedule", "today's schedule", "who is next",
        "next patient", "agenda today", "calendar today"
    ]
    return any(p in q_low for p in schedule_phrases)

def is_explicit_raw_dictation(query: str) -> bool:
    """True if user pastes an encounter dictation or explicitly asks for SOAP note."""
    q_low = query.lower().strip()
    if any(k in q_low for k in ["take a note", "dictate note", "create soap note", "soap note:"]):
        return True
    words = q_low.split()
    return len(words) > 28 and any(k in q_low for k in ["patient presented", "examination", "assessment and plan", "prescribed", "history of present illness"])

def handle_assistant_query(query: str, active_patient: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
    """
    Intelligent clinical reasoning engine for the interactive AI Scribe & Clinical Copilot.
    Processes natural language doctor inquiries across the full scope of clinical reasoning,
    medical decision support, EHR actions, and app workflows.
    """
    q_lower = query.lower().strip()
    today_iso = datetime.date.today().isoformat()

    # 1. ── EXPLICIT APPOINTMENT CANCELLATION COMMAND ─────────────────────────
    if is_explicit_cancel_command(query):
        clinic_appts = get_appointments(today_iso) or get_appointments("")
        matched = match_patient_appointment(query, clinic_appts)
        
        if matched and matched.get("id"):
            appt_id = matched["id"]
            p_name = matched.get("patient_name", "Patient")
            p_time = matched.get("time", "today")
            p_type = matched.get("type", "Appointment")
            
            update_appointment_status(appt_id, "cancelled")
            log_activity(
                action="appointment_cancelled",
                description=f"Cancelled {p_type} for {p_name}",
                patient_name=p_name,
                patient_id=str(matched.get("patient_id", "")),
                detail=f"Time: {p_time}. Status updated to cancelled by clinical assistant.",
                color="red"
            )
            
            reply = (
                f"✅ **Appointment Cancelled**: The **{p_time}** appointment for **{p_name}** "
                f"(*{p_type}*) has been marked as **Cancelled** in your clinic schedule and EHR database."
            )
            
            return {
                "intent": "appointment_cancelled",
                "reply": reply,
                "cancelled_appointment": {**matched, "status": "cancelled"},
                "suggested_prompts": [
                    "Tell me remaining appointments today",
                    f"Book new appointment for {p_name}",
                    f"Open chart for {p_name}"
                ]
            }
        else:
            return {
                "intent": "appointment_cancelled",
                "reply": "Which patient's appointment would you like to cancel? Please specify the patient's name (e.g. *\"Cancel appointment for Sarah Khan\"*).",
                "suggested_prompts": [
                    "Cancel appointment for Sarah Khan",
                    "Cancel appointment for Robert Chen",
                    "Tell me appointments today"
                ]
            }

    # 2. ── EXPLICIT APPOINTMENT BOOKING / CREATION COMMAND ───────────────────
    if is_explicit_book_command(query):
        p_name, p_id, initials = extract_or_match_patient(query, active_patient)
        
        if p_name:
            appt_date = parse_date_slot(q_lower)
            appt_time = parse_time_slot(q_lower)
            appt_type, badge, color = infer_appointment_type(q_lower)
            
            new_appt = create_appointment(
                patient_id=p_id or "pt-001",
                patient_name=p_name,
                initials=initials or "PT",
                time=appt_time,
                duration=20,
                appt_type=appt_type,
                appointment_date=appt_date,
                color=color,
                badge=badge,
                notes="Booked via Clinical AI Assistant"
            )
            
            log_activity(
                action="appointment_booked",
                description=f"Appointment booked for {p_name}",
                patient_name=p_name,
                patient_id=p_id or "pt-001",
                detail=f"{appt_date} at {appt_time} — {appt_type}",
                color="teal"
            )
            
            formatted_date = "today" if appt_date == today_iso else f"on {appt_date}"
            reply = (
                f"✅ **Appointment Confirmed & Created**\n\n"
                f"* **Patient**: **{p_name}** (`{p_id}`)\n"
                f"* **Scheduled Date**: `{appt_date}` ({formatted_date})\n"
                f"* **Scheduled Time**: `{appt_time}`\n"
                f"* **Reason / Type**: {appt_type}\n"
                f"* **Status**: `Upcoming`\n\n"
                f"The visit has been added to your EHR clinic schedule and calendar."
            )
            
            card_appt = {
                "id": new_appt.get("id"),
                "patient_name": p_name,
                "patient_id": p_id,
                "time": appt_time,
                "type": appt_type,
                "status": "upcoming",
                "source": "Clinic EHR"
            }
            
            return {
                "intent": "appointment_created",
                "reply": reply,
                "created_appointment": new_appt,
                "appointments": [card_appt],
                "suggested_prompts": [
                    "Tell me appointments today",
                    f"Open chart for {p_name}",
                    f"Send WhatsApp confirmation to {p_name}"
                ]
            }
        else:
            return {
                "intent": "appointment_creation_prompt",
                "reply": (
                    "Which patient would you like to schedule an appointment for? "
                    "Please provide the patient name and desired time (e.g. *\"Create appointment for Sarah Khan today at 3pm\"* or *\"Book appointment for Robert Chen tomorrow at 10am\"*)."
                ),
                "suggested_prompts": [
                    "Book appointment for Sarah Khan today at 3pm",
                    "Book appointment for Robert Chen tomorrow at 10am",
                    "Tell me appointments today"
                ]
            }

    # 3. ── EXPLICIT SCHEDULE & TIMELINE VIEW ─────────────────────────────────
    if is_explicit_schedule_inquiry(query):
        clinic_appts = get_appointments(today_iso) or get_appointments("")
        cloud_appts = []
        try:
            cloud_appts = fetch_central_appointments(limit=10)
        except Exception:
            pass

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
        reply = (
            f"You have **{count} appointments** scheduled for today ({today_iso}) across Clinic EHR and Central Cloud. Here is your timeline:"
            if count > 0 else
            f"You have no scheduled appointments on your clinic calendar for today ({today_iso})."
        )

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

    # 4. ── EXPLICIT CLINICAL DICTATION / SOAP NOTE ───────────────────────────
    if is_explicit_raw_dictation(query):
        p_name = active_patient.get("name") if active_patient else None
        scribe_res = parse_dictation(query, patient_name=p_name)
        
        display_name = p_name or "the patient"
        reply = (
            f"I've structured a comprehensive clinical SOAP note for **{display_name}** based on your dictation. "
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

    # 5. ── FULL CLINICAL REASONING COPILOT (EVERYTHING ELSE) ─────────────────
    # Identify if a specific patient is being discussed in the query
    target_patient_name = None
    all_pts = load_fhir_patients()
    for p in all_pts:
        pn = p.get("name", {}).get("text", "")
        if pn and pn.lower() in q_lower:
            target_patient_name = pn
            break

    # Build comprehensive clinical system prompt
    system_prompt = build_clinical_system_context(
        active_patient=active_patient,
        target_patient_name=target_patient_name
    )

    llm_reply = generate_text_completion(
        messages=[
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": query}
        ],
        max_tokens=450,
        temperature=0.2
    )

    if llm_reply:
        # Generate contextually relevant suggested follow-up prompts
        follow_ups = []
        if target_patient_name:
            follow_ups.append(f"What are the vitals for {target_patient_name}?")
            follow_ups.append(f"Book follow-up for {target_patient_name}")
            follow_ups.append(f"Dictate clinical note for {target_patient_name}")
        else:
            follow_ups = [
                "Tell me appointments today",
                "Review Sarah Khan's diabetes management",
                "What are the OHIP billing codes for K030?"
            ]

        return {
            "intent": "clinical_reasoning",
            "reply": llm_reply,
            "patient_name": target_patient_name,
            "suggested_prompts": follow_ups
        }

    # Intelligent fallback if LLM is temporarily unreachable
    return {
        "intent": "clinical_reasoning",
        "reply": (
            f"I'm your **Clinical AI Assistant**. I can assist with any medical reasoning or EHR operation:\n\n"
            f"• 🩺 **Clinical Decisions**: Differential workups, pharmacological dosing, and guideline consultations.\n"
            f"• 📋 **Patient Management**: Case analysis for registered patients (Sarah Khan, David Murphy, Robert Chen, etc.).\n"
            f"• 💰 **Ontario OHIP Billing**: Fee schedules (A007, K030, G310) and diagnostic code lookups.\n"
            f"• 📅 **Schedule Actions**: *\"Create appointment for Sarah Khan today at 3pm\"* or *\"Cancel today's appointment\"*."
        ),
        "suggested_prompts": [
            "Review Sarah Khan's diabetes management",
            "What lab tests should I order for David Murphy?",
            "Tell me appointments today"
        ]
    }
