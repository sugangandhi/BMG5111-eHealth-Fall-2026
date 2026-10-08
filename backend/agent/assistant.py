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

def build_clinical_system_context(
    active_patient: Optional[Dict[str, Any]] = None,
    target_patient_name: Optional[str] = None,
    patient_history: Optional[List[Dict[str, Any]]] = None
) -> str:
    """
    Constructs comprehensive real-time clinical context for the LLM Copilot,
    incorporating the EHR patient directory, active clinic roster, Ontario clinical standards,
    current schedule state, and patient's longitudinal encounter history.
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

    # 3. Patient Historical Encounter & Discussion Archive
    history_section = ""
    if patient_history and len(patient_history) > 0:
        history_lines = []
        for item in patient_history[-10:]:
            role_label = "Physician" if item.get("role") in ["doctor", "user"] else "Clinical AI"
            content = (item.get("text") or item.get("content") or "").strip()
            if content:
                truncated = content[:280] + ("..." if len(content) > 280 else "")
                history_lines.append(f"  • [{role_label}]: {truncated}")
        if history_lines:
            history_section = (
                "\nLONGITUDINAL PATIENT CLINICAL HISTORY & PREVIOUS ENCOUNTERS (PERMANENT LOG):\n"
                + "\n".join(history_lines)
                + "\n(Always consider these historical discussions for future clinical predictions, medication continuity, and dosage titration.)\n"
            )

    return f"""You are Prime Care AI, an advanced Clinical AI Copilot & Medical Reasoning Agent for attending physicians practicing in Ontario, Canada.
You possess deep medical clinical judgment, evidence-based reasoning, and complete awareness of the clinic's Electronic Health Record (EHR) database and Ontario healthcare ecosystem.

CLINICAL ENVIRONMENT CONTEXT:
- Today's Date: {today_iso} | Time: {now_str}
- Jurisdiction: Ontario, Canada (CPSO Standards of Practice, Ontario Ministry of Health, Health Canada)
{active_focus}{history_section}
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

def generate_dynamic_suggested_prompts(
    target_patient_name: Optional[str] = None,
    active_patient: Optional[Dict[str, Any]] = None,
    previous_queries: Optional[List[str]] = None,
    offset: int = 0
) -> List[str]:
    """
    Generates tailored, clinically authentic, non-repeating suggested questions
    based on the active patient and discussion context.
    """
    p_name = target_patient_name or (active_patient.get("name") if active_patient else None)
    
    if not p_name:
        all_pool = [
            "Tell me appointments today",
            "Check urgent inbox triage and pending lab alerts",
            "What are the OHIP billing rules for K030 and A007?",
            "Review David Murphy's CKD staging and labs",
            "Check Robert Chen's COPD inhaler regimen",
            "What are the clinical criteria for WSIB Form 8 completion?",
            "How do I document an encounter SOAP note in the EHR?",
            "Review upcoming clinic schedule for tomorrow"
        ]
    else:
        p_low = p_name.lower()
        conds_str = ""
        if active_patient:
            conds_raw = active_patient.get("conditions") or []
            badge = active_patient.get("badge") or ""
            conds_str = (" ".join([str(c) for c in conds_raw]) + " " + str(badge)).lower()

        if "sarah" in p_low or "diabet" in conds_str:
            all_pool = [
                f"What are {p_name}'s latest HbA1c and glycemic trend?",
                f"Review blood pressure & Ramipril dosing for {p_name}",
                f"Check lipid panel and Atorvastatin tolerability for {p_name}",
                f"What is the OHIP fee code (K030) for {p_name}'s diabetes consult?",
                f"Assess microalbuminuria and annual diabetic nephropathy screen for {p_name}",
                f"Book next diabetes review appointment for {p_name}",
                f"Take an encounter note for {p_name}'s diabetes follow-up",
                f"Draft dietary carbohydrate counseling instructions for {p_name}"
            ]
        elif "robert" in p_low or "copd" in conds_str or "lung" in conds_str:
            all_pool = [
                f"Assess COPD exacerbation risk and GOLD staging for {p_name}",
                f"Review current inhaler therapy (Tiotropium/Budesonide) for {p_name}",
                f"Check baseline resting SpO2 and dyspnea grade for {p_name}",
                f"Draft patient instructions for proper inhaler technique for {p_name}",
                f"Assess coronary artery disease stability & cardiac symptoms for {p_name}",
                f"Book follow-up pulmonary check for {p_name}",
                f"Take an encounter note for {p_name}'s respiratory consult",
                f"Review vaccination status (Pneumococcal & Influenza) for {p_name}"
            ]
        elif "david" in p_low or "ckd" in conds_str or "renal" in conds_str or "kidney" in conds_str:
            all_pool = [
                f"What are {p_name}'s latest eGFR and serum creatinine levels?",
                f"Review renal-safe medications and ACE inhibitor titration for {p_name}",
                f"Check serum electrolytes (potassium) & hyperkalemia risk for {p_name}",
                f"Assess urine albumin-to-creatinine ratio (uACR) for {p_name}",
                f"Schedule {p_name}'s quarterly renal review appointment",
                f"Take a clinical progress note for {p_name}'s nephrology follow-up",
                f"Review dietary restrictions (low potassium & phosphorus) for {p_name}",
                f"Order renal ultrasound and repeat metabolic panel for {p_name}"
            ]
        elif "fatima" in p_low or "prenatal" in conds_str or "pregnan" in conds_str:
            all_pool = [
                f"Review {p_name}'s 26-week gestational milestones and growth curve",
                f"Check 75g oral glucose tolerance test (OGTT) protocol for {p_name}",
                f"Assess symphysis-fundal height and fetal heart tones for {p_name}",
                f"Confirm blood group, Rh(D) status and antibody screen for {p_name}",
                f"Take an obstetrical progress note for {p_name}'s prenatal visit",
                f"Book 28-week prenatal check and repeat bloodwork for {p_name}",
                f"Review fetal movement kick counts instructions with {p_name}",
                f"What is the OHIP prenatal fee code (A007/P005) for {p_name}?"
            ]
        elif "marcus" in p_low or "wsib" in conds_str or "wrist" in conds_str or "lumbar" in conds_str:
            all_pool = [
                f"Review {p_name}'s WSIB Form 8 functional abilities & claim status",
                f"Document lumbar spine range of motion and tenderness for {p_name}",
                f"Outline modified duties and lifting restrictions (under 10 lbs) for {p_name}",
                f"Draft WSIB medical progress report & treatment plan for {p_name}",
                f"Schedule physiotherapy reassessment appointment for {p_name}",
                f"Take an occupational health encounter note for {p_name}",
                f"Assess neuropathic symptoms and straight leg raise test for {p_name}",
                f"Review NSAID analgesia and gastroprotection for {p_name}"
            ]
        elif "james" in p_low or "asthma" in conds_str or "pediatric" in conds_str:
            all_pool = [
                f"Review {p_name}'s school asthma & EpiPen emergency action plan",
                f"Check pediatric Asthma Control Test (PACT) score for {p_name}",
                f"Assess Flovent and Ventolin spacer adherence for {p_name}",
                f"Review environmental allergen triggers and eczema topical therapy for {p_name}",
                f"Take a pediatric encounter note for {p_name}",
                f"Check inhaler refill and renew pharmacy prescription for {p_name}",
                f"Book seasonal asthma follow-up for {p_name}",
                f"Provide school administration medical authorization letter for {p_name}"
            ]
        elif "elena" in p_low or "rheumatoid" in conds_str or "arthrit" in conds_str:
            all_pool = [
                f"Check {p_name}'s Methotrexate lab monitoring (CBC, LFTs, ESR/CRP)",
                f"Assess joint stiffness duration and 28-joint disease activity score (DAS28)",
                f"Confirm Folic acid 5mg supplementation timing for {p_name}",
                f"Review DEXA bone mineral density scan & osteoporosis therapy for {p_name}",
                f"Take a clinical note for {p_name}'s rheumatology follow-up",
                f"Schedule {p_name}'s next routine 12-week safety bloodwork",
                f"Assess criteria for biologic or JAK inhibitor step-up therapy for {p_name}",
                f"Book next clinical assessment for {p_name}"
            ]
        elif "marie" in p_low or "mental" in conds_str or "depress" in conds_str or "anxiety" in conds_str:
            all_pool = [
                f"Review {p_name}'s PHQ-9 depression and GAD-7 anxiety scores",
                f"Assess SSRI tolerability, emotional blunting, and sleep hygiene for {p_name}",
                f"Review acute migraine abortive therapy (Triptan) frequency for {p_name}",
                f"Take a confidential mental health progress note for {p_name}",
                f"Discuss CBT and structured psychotherapy referrals for {p_name}",
                f"Book {p_name}'s 4-week mental health follow-up appointment",
                f"Screen for suicidal ideation, safety plan, and crisis resources for {p_name}",
                f"What is the OHIP psychotherapy fee code (K197/K198) for {p_name}?"
            ]
        elif "louise" in p_low or "oncol" in conds_str or "cancer" in conds_str or "breast" in conds_str:
            all_pool = [
                f"Review {p_name}'s post-treatment oncology surveillance interval",
                f"Check routine surveillance bloodwork (CBC, LFTs, Calcium) for {p_name}",
                f"Review endocrine therapy (Tamoxifen/Aromatase inhibitor) adherence & side effects",
                f"Schedule annual bilateral surveillance mammogram for {p_name}",
                f"Assess bone density DEXA scan and bisphosphonate compliance for {p_name}",
                f"Take a clinical progress note for {p_name}'s oncology follow-up",
                f"Book oncology liaison check for {p_name}",
                f"Review lifestyle, lymphedema precautions, and cardiovascular health for {p_name}"
            ]
        elif "michael" in p_low or "oat" in conds_str or "suboxone" in conds_str or "opioid" in conds_str:
            all_pool = [
                f"Review {p_name}'s Suboxone maintenance dosing and craving control",
                f"Check point-of-care urine drug screen status and compliance for {p_name}",
                f"Review Hepatitis C viral load and direct-acting antiviral (DAA) staging",
                f"Confirm HIV viral load suppression and Antiretroviral (ART) compliance for {p_name}",
                f"Take an encounter note for {p_name}'s OAT monthly check-in",
                f"Authorize 30-day OAT pharmacy dispensation and carry doses for {p_name}",
                f"Confirm naloxone kit availability and harm reduction counseling for {p_name}",
                f"Book next addiction medicine review appointment for {p_name}"
            ]
        else:
            all_pool = [
                f"What are {p_name}'s recorded vitals and allergies?",
                f"Review active medications and clinical history for {p_name}",
                f"Take a clinical encounter note for {p_name}",
                f"Book an appointment for {p_name}",
                f"Check recent lab results and diagnostic imaging for {p_name}",
                f"Review immunizations and preventive care schedule for {p_name}",
                f"What are the relevant OHIP assessment fee codes for {p_name}?",
                f"Send WhatsApp follow-up reminder to {p_name}"
            ]

    # Non-repetition filtering: exclude prompts that match past queries
    past_clean = [q.lower().strip() for q in (previous_queries or []) if q]
    unasked = []
    for item in all_pool:
        item_low = item.lower()
        # Check if already asked in recent history
        already_used = any(
            (p in item_low or item_low in p)
            for p in past_clean
        )
        if not already_used:
            unasked.append(item)

    if not unasked:
        unasked = all_pool

    # Apply offset/window to cycle questions cleanly
    num_to_take = min(4, len(unasked))
    start_idx = offset % len(unasked) if len(unasked) > 0 else 0
    selected = []
    for i in range(num_to_take):
        idx = (start_idx + i) % len(unasked)
        if unasked[idx] not in selected:
            selected.append(unasked[idx])

    return selected

def handle_assistant_query(
    query: str,
    active_patient: Optional[Dict[str, Any]] = None,
    previous_queries: Optional[List[str]] = None,
    patient_history: Optional[List[Dict[str, Any]]] = None
) -> Dict[str, Any]:
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
        target_patient_name=target_patient_name,
        patient_history=patient_history
    )

    llm_messages = [{"role": "system", "content": system_prompt}]
    if patient_history and len(patient_history) > 0:
        for turn in patient_history[-4:]:
            r = "user" if turn.get("role") in ["doctor", "user"] else "assistant"
            txt = (turn.get("text") or turn.get("content") or "").strip()
            if txt:
                llm_messages.append({"role": r, "content": txt[:350]})
    llm_messages.append({"role": "user", "content": query})

    llm_reply = generate_text_completion(
        messages=llm_messages,
        max_tokens=450,
        temperature=0.2
    )



    combined_past = list(previous_queries or []) + [query]
    resolved_patient_name = target_patient_name or (active_patient.get("name") if active_patient else None)

    if llm_reply:
        follow_ups = generate_dynamic_suggested_prompts(
            target_patient_name=resolved_patient_name,
            active_patient=active_patient,
            previous_queries=combined_past
        )
        return {
            "intent": "clinical_reasoning",
            "reply": llm_reply,
            "patient_name": resolved_patient_name,
            "suggested_prompts": follow_ups
        }

    follow_ups = generate_dynamic_suggested_prompts(
        target_patient_name=resolved_patient_name,
        active_patient=active_patient,
        previous_queries=combined_past
    )

    fallback_reply = build_clinical_fallback_response(
        query=query,
        target_patient_name=resolved_patient_name,
        active_patient=active_patient
    )

    return {
        "intent": "clinical_reasoning",
        "reply": fallback_reply,
        "patient_name": resolved_patient_name,
        "suggested_prompts": follow_ups
    }

def build_clinical_fallback_response(
    query: str,
    target_patient_name: Optional[str] = None,
    active_patient: Optional[Dict[str, Any]] = None
) -> str:
    """
    High-fidelity clinical reasoning safety fallback when both cloud OpenAI
    (e.g. credit exhaustion 429) and local Ollama are unreachable.
    Provides verified clinical guidelines and notifies clinician of engine status.
    """
    q_low = query.lower()
    p_name = target_patient_name or (active_patient.get("name") if active_patient else "the patient")

    quota_notice = (
        "> 💡 **Clinical Engine Notice**: Cloud OpenAI reported credit balance exhaustion (429 Insufficient Quota). "
        "The following instructions were synthesized from Prime Care EHR clinical guidelines. "
        "Tap **⚙️ Settings** to enter a fresh OpenAI API key or top up billing credits.\n\n"
    )

    if any(k in q_low for k in ["inhaler", "copd", "asthma", "salbutamol", "tiotropium", "spiriva", "ventolin"]):
        return (
            quota_notice +
            f"### Patient Instructions: Proper Inhaler Technique for {p_name}\n\n"
            f"**Prescribed COPD / Respiratory Regimen:**\n"
            f"• **Controller (LAMA)**: Tiotropium (Spiriva) 18 mcg — **1 inhalation once daily** at the same time each morning. Prevents bronchospasm.\n"
            f"• **Reliever (SABA)**: Salbutamol (Ventolin) 100 mcg — **1–2 puffs every 4–6 hours PRN** for acute shortness of breath or wheezing.\n\n"
            f"**Step-by-Step Administration Guide:**\n"
            f"1. **Preparation**: Sit or stand upright. Remove cap and inspect mouthpiece. For MDI (Ventolin), shake vigorously 5 seconds.\n"
            f"2. **Exhale**: Breathe out completely, away from the inhaler, emptying lungs comfortably.\n"
            f"3. **Placement**: Place mouthpiece between teeth, closing lips tightly around it to create an airtight seal (do not bite or obstruct vents).\n"
            f"4. **Actuation & Inhalation**: Press canister firmly once while taking a slow, deep breath in over 3 to 5 seconds.\n"
            f"5. **Breath-Hold**: Remove inhaler and hold breath for **10 full seconds** (or as long as comfortable) so medication settles deep into the airways.\n"
            f"6. **Interval**: If taking a second puff of Ventolin, wait **1 full minute** before repeating steps 2–5.\n\n"
            f"**Safety & Best Practices:**\n"
            f"• **Valved Holding Chamber (Spacer)**: Recommended with Ventolin to maximize alveolar deposition and reduce throat irritation.\n"
            f"• **Mouth Rinse**: If using combination corticosteroid inhalers, rinse mouth with water and spit out to prevent oral thrush.\n"
            f"• **Warning Signs**: If shortness of breath does not improve after 2 doses of rescue inhaler, or if lips turn bluish, seek urgent medical care immediately."
        )

    if any(k in q_low for k in ["hypertension", "blood pressure", "ramipril", "amlodipine"]):
        return (
            quota_notice +
            f"### Clinical Guidance: Blood Pressure Management for {p_name}\n\n"
            f"• **Target BP**: < 130/80 mmHg (Diabetes Canada / Hypertension Canada guidelines).\n"
            f"• **Home Monitoring**: Record seated BP twice daily (morning and evening) after 5 minutes of rest.\n"
            f"• **Lifestyle**: DASH diet, sodium < 2,000 mg/day, 150 min/week moderate aerobic activity.\n"
            f"• **Red Flags**: SBP > 180 or DBP > 120 with chest pain, vision changes, or shortness of breath requires immediate emergency evaluation."
        )

    if any(k in q_low for k in ["diabetes", "a1c", "metformin", "glucose"]):
        return (
            quota_notice +
            f"### Clinical Guidance: Type 2 Diabetes Management for {p_name}\n\n"
            f"• **Target HbA1c**: ≤ 7.0% for most adults to prevent microvascular complications.\n"
            f"• **First-Line Pharmacotherapy**: Metformin 500 mg BID with meals, titrating to 1,000 mg BID as tolerated; consider SGLT2i or GLP-1 RA for cardiorenal protection.\n"
            f"• **Monitoring**: Fasting blood glucose (target 4.0–7.0 mmol/L) and 2-hour postprandial (target 5.0–10.0 mmol/L).\n"
            f"• **Annual Screening**: Urine albumin-to-creatinine ratio (uACR), eGFR, monofilament foot exam, and dilated eye examination."
        )

    return (
        quota_notice +
        f"I'm your **Clinical AI Assistant**. Here are the primary actions available for {p_name}:\n\n"
        f"• 🩺 **Clinical Decisions**: Differential workups, pharmacological dosing, and guideline consultations.\n"
        f"• 📋 **Patient Management**: Case analysis for registered patients (Sarah Khan, David Murphy, Robert Chen, etc.).\n"
        f"• 💰 **Ontario OHIP Billing**: Fee schedules (A007, K030, G310) and diagnostic code lookups.\n"
        f"• 📅 **Schedule Actions**: *\"Create appointment for Sarah Khan today at 3pm\"* or *\"Cancel today's appointment\"*."
    )
