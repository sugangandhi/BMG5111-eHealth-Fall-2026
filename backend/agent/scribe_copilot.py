import os
import json
import re
from datetime import datetime, timedelta
from typing import Dict, Any, List, Optional
from pydantic import BaseModel

from agent.patient_matcher import send_whatsapp_message
from fhir.patient_loader import _load as load_patients, list_patients, get_patient
from db.database import get_appointments, create_appointment, log_activity

# Optional OpenAI / Ollama client
try:
    from openai import OpenAI
    _base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
    _client = OpenAI(base_url=_base_url, api_key="local")
    MODEL = "gemma2:2b"
except Exception:
    _client = None
    MODEL = "gemma2:2b"

class CopilotRequest(BaseModel):
    message: str
    history: List[Dict[str, str]] = []
    patient_id: Optional[str] = None

class CopilotResponse(BaseModel):
    reply: str
    action_type: str  # "navigate", "whatsapp_sent", "appointment_booked", "schedule_checked", "patient_info", "general_reply"
    action_data: Optional[Dict[str, Any]] = None

def find_patient_by_name(name_query: str) -> Optional[Dict[str, Any]]:
    """Fuzzy matches a patient name against synthetic FHIR database."""
    if not name_query:
        return None
    q = name_query.lower().strip()
    patients = load_patients()
    
    for p in patients:
        full = p["name"]["text"].lower()
        if q == full or q in full:
            return p
            
    for p in patients:
        given = [g.lower() for g in p["name"].get("given", [])]
        family = p["name"].get("family", "").lower()
        if any(g in q for g in given) or family in q:
            return p
            
    return None

def process_copilot_turn(message: str, history: List[Dict[str, str]] = [], patient_id: Optional[str] = None) -> CopilotResponse:
    text = message.strip()
    text_lower = text.lower()

    # ──────────────────────────────────────────────────────────────────────────
    # 1. INTENT: APP NAVIGATION & SCREEN SWITCHING ("WORK AROUND THE APP")
    # ──────────────────────────────────────────────────────────────────────────
    nav_map = [
        ("dashboard", ["dashboard", "home", "main screen", "overview"], "Dashboard"),
        ("inbox", ["inbox", "secure inbox", "messages", "inbound message", "emails", "unread message"], "Secure Inbox"),
        ("calendar", ["calendar", "smart calendar", "schedule calendar"], "Smart Calendar"),
        ("billing", ["billing", "claims", "revenue", "finances", "claim"], "Billing Dashboard"),
        ("twin", ["twin", "3d twin", "digital twin", "anatomy", "ct scan", "mri"], "3D Digital Twin"),
        ("formFiller", ["form", "form filler", "ocr", "intake", "scanner", "intake form"], "Intake OCR Engine"),
        ("referral", ["referral", "referrals", "triage", "referral checker"], "Referral AI Triage"),
        ("inbound", ["inbound", "chart chat", "inbound summary"], "Inbound Summary & Chat")
    ]

    is_nav = any(k in text_lower for k in [
        "go to", "take me to", "navigate to", "open", "switch to", "show me the", "view the", "show", "bring up", "view", "display"
    ]) or text_lower in [
        "inbox", "billing", "twin", "3d twin", "dashboard", "home", "calendar", "form", "ocr", "referral", "summary", "messages", "claims"
    ]

    for tab_key, triggers, tab_title in nav_map:
        if any(t in text_lower for t in triggers):
            if is_nav or any(text_lower == t for t in triggers):
                return CopilotResponse(
                    reply=f"🧭 Navigating to **{tab_title}** right away.",
                    action_type="navigate",
                    action_data={"tab": tab_key, "label": tab_title}
                )

    # ──────────────────────────────────────────────────────────────────────────
    # 2. INTENT: SEND WHATSAPP MESSAGE TO PATIENT
    # ──────────────────────────────────────────────────────────────────────────
    if "whatsapp" in text_lower or ("send" in text_lower and ("message" in text_lower or "text" in text_lower)):
        matched_patient = None
        target_name = ""
        for p in load_patients():
            p_name = p["name"]["text"]
            if p_name.lower() in text_lower or p["name"].get("family", "").lower() in text_lower:
                matched_patient = p
                target_name = p_name
                break
                
        if not matched_patient and patient_id:
            matched_patient = get_patient(patient_id)
            if matched_patient:
                target_name = matched_patient["name"]["text"]
                
        if not matched_patient:
            matched_patient = load_patients()[0]  # Default Sarah Khan
            target_name = matched_patient["name"]["text"]

        phone = matched_patient.get("phone", "613-555-0192")
        
        # Extract message body
        msg_body = ""
        saying_match = re.search(r"(?:saying|tell them|message|text)\s*(?:that|is|:)?\s*(.+)$", text, re.IGNORECASE)
        if saying_match:
            msg_body = saying_match.group(1).strip().strip('"').strip("'")
        else:
            msg_body = "Hello from e-Hospital clinic. Please contact our office regarding your upcoming consultation."

        delivered = send_whatsapp_message(phone, msg_body)
        
        log_activity(
            action="whatsapp_dispatched",
            description=f"Hospital Staff Copilot sent WhatsApp to {target_name}",
            patient_name=target_name,
            patient_id=matched_patient.get("id", "pt-001"),
            detail=f"Phone: {phone} — Message: \"{msg_body[:80]}...\"",
            color="emerald"
        )
        
        reply = (
            f"📱 **WhatsApp Message Dispatched!**\n\n"
            f"• **Recipient:** {target_name} ({phone})\n"
            f"• **Message:** \"{msg_body}\"\n"
            f"• **Status:** {'Delivered via WhatsApp API' if delivered else 'Simulated Dispatch Queued'}"
        )
        
        return CopilotResponse(
            reply=reply,
            action_type="whatsapp_sent",
            action_data={
                "patient_name": target_name,
                "phone": phone,
                "message": msg_body,
                "delivered": delivered,
                "timestamp": datetime.now().strftime("%I:%M %p")
            }
        )

    # ──────────────────────────────────────────────────────────────────────────
    # 3. INTENT: CHECK APPOINTMENTS / AVAILABLE SLOTS / SCHEDULE
    # ──────────────────────────────────────────────────────────────────────────
    if any(k in text_lower for k in [
        "available appointment", "available slot", "check appointment", "my schedule", 
        "what appointment", "show appointment", "free slot", "open slot", "appointments today", "any appointment"
    ]):
        today_str = datetime.now().strftime("%Y-%m-%d")
        target_date = today_str
        date_label = "today"
        
        if "tomorrow" in text_lower:
            tomorrow = datetime.now() + timedelta(days=1)
            target_date = tomorrow.strftime("%Y-%m-%d")
            date_label = "tomorrow"
        elif "yesterday" in text_lower:
            yesterday = datetime.now() - timedelta(days=1)
            target_date = yesterday.strftime("%Y-%m-%d")
            date_label = "yesterday"
            
        all_appts = get_appointments(target_date)
        if not all_appts:
            all_appts = get_appointments(None)
            date_label = "upcoming"
            
        if all_appts:
            lines = [f"📅 **Clinic Schedule for {date_label.title()} ({len(all_appts)} appointments):**\n"]
            booked_times = []
            for a in all_appts[:6]:
                p_name = a.get("patient_name", "Patient")
                t = a.get("time", "Time TBD")
                typ = a.get("type", "Consultation")
                stat = a.get("status", "scheduled").upper()
                lines.append(f"• **{t}** — {p_name} ({typ}) [{stat}]")
                booked_times.append(t)
                
            standard_slots = ["09:00 AM", "10:00 AM", "11:00 AM", "01:00 PM", "02:00 PM", "03:00 PM", "04:00 PM"]
            open_slots = [s for s in standard_slots if not any(s.split()[0] in b for b in booked_times)]
            if open_slots:
                lines.append(f"\n💡 **Available Free Slots:** {', '.join(open_slots[:4])}")
                
            reply = "\n".join(lines)
        else:
            reply = f"📅 **No appointments scheduled for {date_label}.**\nAll slots are currently open between 09:00 AM and 05:00 PM."
            
        return CopilotResponse(
            reply=reply,
            action_type="schedule_checked",
            action_data={
                "date": target_date,
                "date_label": date_label,
                "appointments": all_appts
            }
        )

    # ──────────────────────────────────────────────────────────────────────────
    # 4. INTENT: BOOK APPOINTMENT
    # ──────────────────────────────────────────────────────────────────────────
    if ("book" in text_lower or "schedule" in text_lower) and ("appointment" in text_lower or "consult" in text_lower or "visit" in text_lower or "slot" in text_lower):
        matched_patient = None
        patient_name = "Walk-in Patient"
        p_id = "pt-walkin"
        
        for p in load_patients():
            p_name = p["name"]["text"]
            if p_name.lower() in text_lower or p["name"].get("family", "").lower() in text_lower:
                matched_patient = p
                patient_name = p_name
                p_id = p["id"]
                break
                
        if not matched_patient and patient_id:
            matched_patient = get_patient(patient_id)
            if matched_patient:
                patient_name = matched_patient["name"]["text"]
                p_id = matched_patient["id"]

        appt_date = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        if "today" in text_lower:
            appt_date = datetime.now().strftime("%Y-%m-%d")
        elif "tomorrow" in text_lower:
            appt_date = (datetime.now() + timedelta(days=1)).strftime("%Y-%m-%d")
        elif "next week" in text_lower:
            appt_date = (datetime.now() + timedelta(days=7)).strftime("%Y-%m-%d")
        else:
            d_match = re.search(r"\b202\d-\d{2}-\d{2}\b", text)
            if d_match:
                appt_date = d_match.group(0)

        time_str = "02:00 PM"
        t_match = re.search(r"\b(\d{1,2}(?::\d{2})?\s*(?:am|pm|AM|PM))\b", text)
        if t_match:
            time_str = t_match.group(1).upper()
            if ":" not in time_str:
                parts = time_str.split()
                time_str = f"{parts[0]}:00 {parts[1]}"
                
        appt_type = "Clinical Follow-up"
        if "cardio" in text_lower or "chest" in text_lower or "heart" in text_lower:
            appt_type = "Cardiology Assessment"
        elif "diabet" in text_lower or "sugar" in text_lower:
            appt_type = "Diabetes Review"
        elif "neuro" in text_lower or "headache" in text_lower:
            appt_type = "Neurology Consultation"
        elif "annual" in text_lower or "physical" in text_lower:
            appt_type = "Annual Physical Exam"

        initials = "".join([part[0] for part in patient_name.split()[:2]]).upper()
        new_appt = create_appointment(
            patient_id=p_id,
            patient_name=patient_name,
            initials=initials,
            time=time_str,
            duration=30,
            type=appt_type,
            appointment_date=appt_date,
            color="teal",
            badge="Confirmed",
            notes=f"Booked via Hospital Staff Chatbot: {text[:60]}"
        )
        
        log_activity(
            action="appointment_booked",
            description=f"Hospital Staff Chatbot booked appointment for {patient_name}",
            patient_name=patient_name,
            patient_id=p_id,
            detail=f"{appt_date} at {time_str} — {appt_type}",
            color="teal"
        )
        
        reply = (
            f"✅ **Appointment Confirmed!**\n\n"
            f"• **Patient:** {patient_name}\n"
            f"• **Date:** {appt_date}\n"
            f"• **Time:** {time_str} (30 mins)\n"
            f"• **Service:** {appt_type}\n"
            f"• **Calendar:** Synced to Smart Calendar"
        )
        
        return CopilotResponse(
            reply=reply,
            action_type="appointment_booked",
            action_data={
                "appointment": new_appt,
                "patient_name": patient_name,
                "date": appt_date,
                "time": time_str,
                "type": appt_type
            }
        )

    # ──────────────────────────────────────────────────────────────────────────
    # 5. INTENT: PATIENT CHART / LABS / VITALS INQUIRY
    # ──────────────────────────────────────────────────────────────────────────
    if any(k in text_lower for k in ["blood pressure", "medication", "allerg", "history", "vitals", "diagnosis", "who is", "patient details", "lab results"]):
        matched_patient = None
        for p in load_patients():
            p_name = p["name"]["text"]
            if p_name.lower() in text_lower or p["name"].get("family", "").lower() in text_lower:
                matched_patient = p
                break
                
        if not matched_patient and patient_id:
            matched_patient = get_patient(patient_id)
            
        if not matched_patient:
            matched_patient = load_patients()[0]

        p_name = matched_patient["name"]["text"]
        
        if "medication" in text_lower:
            meds = matched_patient.get("medications", [])
            med_list = [f"• **{m['name']}** {m['dose']} {m['frequency']} ({m.get('indication', 'Therapy')})" for m in meds]
            reply = f"💊 **Active Medications for {p_name}:**\n\n" + "\n".join(med_list)
        elif "allerg" in text_lower:
            allergies = matched_patient.get("allergies", ["NKDA"])
            reply = f"⚠️ **Documented Allergies for {p_name}:**\n\n" + "\n".join([f"• {a}" for a in allergies])
        elif "blood pressure" in text_lower or "vital" in text_lower:
            labs = matched_patient.get("labs", [])
            reply = f"📊 **Latest Vitals & Lab Markers for {p_name}:**\n\n"
            for lab in labs[:5]:
                reply += f"• **{lab['test']}:** {lab['value']} {lab['unit']} ({lab.get('flag', 'NORMAL')})\n"
        else:
            conds = [c["display"] for c in matched_patient.get("conditions", [])]
            reply = (
                f"👤 **Patient Profile: {p_name}**\n\n"
                f"• **DOB:** {matched_patient['birthDate']} ({matched_patient['gender']})\n"
                f"• **OHIP:** {matched_patient.get('ohip', 'N/A')}\n"
                f"• **Conditions:** {', '.join(conds) if conds else 'None on file'}\n"
                f"• **Phone:** {matched_patient.get('phone', 'N/A')}"
            )
            
        return CopilotResponse(
            reply=reply,
            action_type="patient_info",
            action_data={"patient": matched_patient}
        )

    # ──────────────────────────────────────────────────────────────────────────
    # 6. GENERAL HOSPITAL STAFF CONVERSATION / CLINICAL Q&A
    # ──────────────────────────────────────────────────────────────────────────
    if _client:
        try:
            sys_prompt = (
                "You are the e-Hospital AI Assistant for hospital clinical staff. "
                "You help doctors, nurses, and coordinators with hospital navigation, appointments, "
                "patient lookups, and clinical guidelines. Keep answers concise, clear, and actionable."
            )
            messages = [{"role": "system", "content": sys_prompt}]
            for h in history[-4:]:
                messages.append({"role": h.get("role", "user"), "content": h.get("content", "")})
            messages.append({"role": "user", "content": text})
            
            response = _client.chat.completions.create(
                model=MODEL,
                messages=messages,
                temperature=0.2,
                timeout=4.0
            )
            ai_reply = response.choices[0].message.content.strip()
            return CopilotResponse(
                reply=ai_reply,
                action_type="general_reply"
            )
        except Exception:
            pass

    # Heuristic fallback response
    fallback_reply = (
        f"I received your instruction: *\"{text}\"*\n\n"
        f"**Actions you can ask me to do:**\n"
        f"• 🧭 **Navigate the App:** *\"Go to Inbox\"*, *\"Open Billing\"*, *\"Show 3D Twin\"*, *\"Go to Dashboard\"*\n"
        f"• 📱 **WhatsApp Patients:** *\"Send a WhatsApp message to Sarah Khan saying her test results are ready\"*\n"
        f"• 📅 **Manage Schedule:** *\"What appointments do I have today?\"*, *\"Book appointment for Sarah Khan tomorrow at 3 PM\"*\n"
        f"• 👤 **Patient Lookup:** *\"What medications is Sarah Khan taking?\"*, *\"Show John Doe vitals\"*"
    )
    return CopilotResponse(
        reply=fallback_reply,
        action_type="general_reply"
    )
