"""
SQLAlchemy database persistence layer for MedOffice AI.
"""
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Dict, List, Optional
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from .models import Base, User, Appointment, ActivityLog, FormSubmission, Claim
from auth.jwt import get_password_hash, verify_password

DB_PATH = Path(__file__).parent / "medoffice.db"
# Use check_same_thread=False for SQLite in FastAPI
engine = create_engine(f"sqlite:///{DB_PATH}", connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# ─── Seed Data ────────────────────────────────────────────────────────────────
DEMO_USERS = [
    {
        "username": "dr.patel",
        "password": "medoffice2026",
        "full_name": "Dr. Anika Patel",
        "initials": "AP",
        "role": "Family Physician",
        "clinic": "Ottawa Family Health Team",
        "cpso": "92841"
    }
]

_TODAY_APPTS = [
    ("pt-001", "Sarah Khan",      "SK", "08:30", 20, "Type 2 Diabetes follow-up",           "completed",   "blue",   "Diabetes"),
    ("pt-004", "Robert Chen",     "RC", "09:00", 30, "COPD management",                     "completed",   "orange", "COPD"),
    ("pt-005", "Fatima Hassan",   "FH", "09:45", 20, "Prenatal visit — 26 weeks",           "completed",   "pink",   "Prenatal"),
    ("pt-006", "David Murphy",    "DM", "10:15", 30, "CKD Stage 3b quarterly review",       "in-progress", "red",    "CKD"),
    ("pt-008", "James Okafor",    "JO", "11:00", 20, "Asthma + anaphylaxis school form",    "upcoming",    "blue",   "Asthma"),
    ("pt-002", "Marcus Webb",      "MW", "11:30", 15, "WSIB Form 8 follow-up",               "upcoming",    "orange", "WSIB"),
    ("pt-003", "Marie Tremblay",  "MT", "14:00", 30, "Mental health follow-up",             "upcoming",    "purple", "MH"),
    ("pt-007", "Elena Petrov",    "EP", "14:45", 20, "RA monitoring + labs",                "upcoming",    "blue",   "RA"),
    ("pt-009", "Louise Martin",   "LM", "15:30", 30, "Preventive care + oncology liaison",  "upcoming",    "green",  "Oncology"),
    ("pt-010", "Michael Santos",  "MS", "16:15", 20, "OAT monthly check-in",                "upcoming",    "teal",   "OAT"),
]

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db() -> None:
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    # Seed Demo Users
    for u in DEMO_USERS:
        if not db.query(User).filter(User.username == u["username"]).first():
            user = User(
                username=u["username"],
                password_hash=get_password_hash(u["password"]),
                full_name=u["full_name"],
                initials=u["initials"],
                role=u["role"],
                clinic=u["clinic"],
                cpso=u["cpso"],
            )
            db.add(user)
        db.commit()
    
    today_str = date.today().isoformat()
    if db.query(Appointment).filter(Appointment.appointment_date == today_str).count() == 0:
        for r in _TODAY_APPTS:
            db.add(Appointment(
                patient_id=r[0], patient_name=r[1], initials=r[2], time=r[3], 
                duration=r[4], type=r[5], status=r[6], color=r[7], badge=r[8],
                appointment_date=today_str,
            ))
        db.commit()
    db.close()

def validate_credentials(username: str, password: str) -> Optional[Dict]:
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    if user and verify_password(password, user.password_hash):
        ret = {
            "name": user.full_name,
            "initials": user.initials,
            "role": user.role,
            "clinic": user.clinic,
            "cpso": user.cpso
        }
        db.close()
        return ret
    db.close()
    return None

def get_appointments(appt_date: Optional[str] = None) -> List[Dict]:
    d = appt_date or date.today().isoformat()
    db = SessionLocal()
    appts = db.query(Appointment).filter(Appointment.appointment_date == d).order_by(Appointment.time).all()
    # converting to dict
    res = []
    for a in appts:
        res.append({c.name: getattr(a, c.name) for c in a.__table__.columns})
    db.close()
    return res

def update_appointment_status(appt_id: int, status: str) -> Optional[Dict]:
    db = SessionLocal()
    a = db.query(Appointment).filter(Appointment.id == appt_id).first()
    if a and status in {"upcoming", "in-progress", "completed", "cancelled"}:
        a.status = status
        db.commit()
        db.refresh(a)
        res = {c.name: getattr(a, c.name) for c in a.__table__.columns}
        db.close()
        return res
    db.close()
    return None

def create_appointment(patient_id: str, patient_name: str, initials: str,
                       time: str, duration: int, appt_type: str,
                       appointment_date: str, color: str = "blue",
                       badge: str = "", notes: str = "") -> Dict:
    db = SessionLocal()
    a = Appointment(
        patient_id=patient_id, patient_name=patient_name, initials=initials,
        time=time, duration=duration, type=appt_type, appointment_date=appointment_date,
        status="upcoming", color=color, badge=badge, notes=notes
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    res = {c.name: getattr(a, c.name) for c in a.__table__.columns}
    db.close()
    return res

def update_appointment(appt_id: int, date: str, time: str, appt_type: str) -> Optional[Dict]:
    db = SessionLocal()
    a = db.query(Appointment).filter(Appointment.id == appt_id).first()
    if a:
        if date: a.appointment_date = date
        if time: a.time = time
        if appt_type: a.type = appt_type
        db.commit()
        db.refresh(a)
        res = {c.name: getattr(a, c.name) for c in a.__table__.columns}
        db.close()
        return res
    db.close()
    return None

def delete_appointment(appt_id: int) -> bool:
    db = SessionLocal()
    a = db.query(Appointment).filter(Appointment.id == appt_id).first()
    if a:
        db.delete(a)
        db.commit()
        db.close()
        return True
    db.close()
    return False

def log_activity(action: str, description: str, patient_name: str = "",
                 patient_id: str = "", detail: str = "", color: str = "teal") -> None:
    db = SessionLocal()
    al = ActivityLog(action=action, description=description, patient_name=patient_name,
                     patient_id=patient_id, detail=detail, color=color)
    db.add(al)
    db.commit()
    db.close()

def get_activity(limit: int = 10) -> List[Dict]:
    db = SessionLocal()
    logs = db.query(ActivityLog).order_by(ActivityLog.created_at.desc()).limit(limit).all()
    res = []
    for l in logs:
        d = {c.name: getattr(l, c.name) for c in l.__table__.columns}
        if d.get("created_at"):
            d['secs_ago'] = int((datetime.utcnow() - l.created_at).total_seconds())
        else:
            d['secs_ago'] = 0
        if "created_at" in d:
             d["created_at"] = str(d["created_at"])
        res.append(d)
    db.close()
    return res

def log_form_submission(patient_id: str, patient_name: str, form_type: str,
                        fields_filled: int, fields_total: int) -> None:
    db = SessionLocal()
    fs = FormSubmission(patient_id=patient_id, patient_name=patient_name, 
                        form_type=form_type, fields_filled=fields_filled, 
                        fields_total=fields_total)
    db.add(fs)
    db.commit()
    db.close()

def get_dashboard_stats() -> Dict[str, Any]:
    today = date.today().isoformat()
    db = SessionLocal()
    
    patients_seen = db.query(Appointment).filter(
        Appointment.appointment_date == today, 
        Appointment.status.in_(['completed', 'in-progress'])
    ).count()

    forms_today = db.query(FormSubmission).filter(
        FormSubmission.submission_date == today
    ).count()

    # using text comparison for date part
    pending_referrals = db.query(ActivityLog).filter(
        ActivityLog.action == 'referral_flagged'
    ).count()
    if pending_referrals == 0:
        pending_referrals = 3 # demo logic

    completed = db.query(Appointment).filter(Appointment.appointment_date == today, Appointment.status == 'completed').count()
    in_progress = db.query(Appointment).filter(Appointment.appointment_date == today, Appointment.status == 'in-progress').count()
    upcoming = db.query(Appointment).filter(Appointment.appointment_date == today, Appointment.status == 'upcoming').count()
    total = db.query(Appointment).filter(Appointment.appointment_date == today).count()

    db.close()
    
    return {
        "patients_today": patients_seen,
        "forms_today": forms_today,
        "pending_referrals": pending_referrals,
        "time_saved_min": forms_today * 15,
        "completed": completed,
        "in_progress": in_progress,
        "upcoming": upcoming,
        "total_today": total,
    }

def get_chart_data() -> Dict[str, Any]:
    today = date.today()
    monday = today - timedelta(days=today.weekday())
    labels, forms_data, patients_data = [], [], []
    
    db = SessionLocal()
    for i in range(5):
        day = monday + timedelta(days=i)
        if day > today:
            break
        ds = day.isoformat()
        labels.append(day.strftime("%a %b %d"))
        
        forms = db.query(FormSubmission).filter(FormSubmission.submission_date == ds).count()
        patients = db.query(Appointment).filter(Appointment.appointment_date == ds, Appointment.status.in_(['completed', 'in-progress'])).count()
        
        forms_data.append(forms)
        patients_data.append(patients)
    db.close()

    return {"labels": labels, "forms": forms_data, "patients": patients_data}

# ── Claims (OHIP) ────────────────────────────────────────────────────────────

def get_claims() -> List[Dict]:
    db = SessionLocal()
    from db.models import Claim
    claims = db.query(Claim).order_by(Claim.created_at.desc()).all()
    res = []
    import json
    for c in claims:
        d = {col.name: getattr(c, col.name) for col in c.__table__.columns}
        d["ohip_diagnostic_codes"] = json.loads(d["ohip_diagnostic_codes"])
        d["ohip_fee_codes"] = json.loads(d["ohip_fee_codes"])
        d["warnings"] = json.loads(d["warnings"])
        d["created_at"] = str(d["created_at"])
        # Format for frontend
        d["id"] = d["claim_id"] 
        d["patient"] = d["patient_name"]
        d["date"] = d["date_of_service"]
        res.append(d)
    db.close()
    return res

def create_claim(claim_id: str, patient_name: str, date_of_service: str, 
                 health_card_number: str, version_code: str,
                 ohip_diagnostic_codes: List[str], ohip_fee_codes: List[str], 
                 revenue: int, warnings: List[str]) -> Dict:
    import json
    db = SessionLocal()
    from db.models import Claim
    c = Claim(
        claim_id=claim_id,
        patient_name=patient_name,
        health_card_number=health_card_number,
        version_code=version_code,
        date_of_service=date_of_service,
        ohip_diagnostic_codes=json.dumps(ohip_diagnostic_codes),
        ohip_fee_codes=json.dumps(ohip_fee_codes),
        revenue=revenue,
        status="Pending Review",
        warnings=json.dumps(warnings)
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    
    d = {col.name: getattr(c, col.name) for col in c.__table__.columns}
    d["ohip_diagnostic_codes"] = ohip_diagnostic_codes
    d["ohip_fee_codes"] = ohip_fee_codes
    d["warnings"] = warnings
    d["created_at"] = str(d["created_at"])
    d["id"] = d["claim_id"]
    d["patient"] = d["patient_name"]
    d["date"] = d["date_of_service"]
    
    db.close()
    return d

def update_claim_status(claim_id: str, status: str) -> Optional[Dict]:
    import json
    db = SessionLocal()
    from db.models import Claim
    c = db.query(Claim).filter(Claim.claim_id == claim_id).first()
    if c:
        c.status = status
        db.commit()
        db.refresh(c)
        d = {col.name: getattr(c, col.name) for col in c.__table__.columns}
        d["ohip_diagnostic_codes"] = json.loads(d["ohip_diagnostic_codes"])
        d["ohip_fee_codes"] = json.loads(d["ohip_fee_codes"])
        d["warnings"] = json.loads(d["warnings"])
        d["created_at"] = str(d["created_at"])
        d["id"] = d["claim_id"]
        d["patient"] = d["patient_name"]
        d["date"] = d["date_of_service"]
        db.close()
        return d
    db.close()
    return None

def get_claim_templates() -> List[Dict]:
    db = SessionLocal()
    from db.models import ClaimTemplate
    templates = db.query(ClaimTemplate).order_by(ClaimTemplate.created_at.desc()).all()
    res = []
    import json
    for t in templates:
        d = {col.name: getattr(t, col.name) for col in t.__table__.columns}
        d["ohip_diagnostic_codes"] = json.loads(d["ohip_diagnostic_codes"])
        d["ohip_fee_codes"] = json.loads(d["ohip_fee_codes"])
        d["created_at"] = str(d["created_at"])
        res.append(d)
    db.close()
    return res

def create_claim_template(name: str, ohip_diagnostic_codes: List[str], ohip_fee_codes: List[str], revenue: int) -> Dict:
    import json
    db = SessionLocal()
    from db.models import ClaimTemplate
    t = ClaimTemplate(
        name=name,
        ohip_diagnostic_codes=json.dumps(ohip_diagnostic_codes),
        ohip_fee_codes=json.dumps(ohip_fee_codes),
        revenue=revenue
    )
    db.add(t)
    db.commit()
    db.refresh(t)
    d = {col.name: getattr(t, col.name) for col in t.__table__.columns}
    d["ohip_diagnostic_codes"] = ohip_diagnostic_codes
    d["ohip_fee_codes"] = ohip_fee_codes
    d["created_at"] = str(d["created_at"])
    db.close()
    return d

def get_billing_analytics() -> Dict[str, Any]:
    db = SessionLocal()
    from db.models import Claim
    from sqlalchemy import func
    
    # Revenue tracking
    paid = db.query(func.sum(Claim.revenue)).filter(Claim.status == "Paid").scalar() or 0
    pending = db.query(func.sum(Claim.revenue)).filter(Claim.status.in_(["Pending Review", "Submitted to MCEDT"])).scalar() or 0
    rejected = db.query(func.sum(Claim.revenue)).filter(Claim.status == "Rejected").scalar() or 0
    
    # Count tracking
    total_claims = db.query(Claim).count()
    rejected_claims = db.query(Claim).filter(Claim.status == "Rejected").count()
    rejection_rate = (rejected_claims / total_claims * 100) if total_claims > 0 else 0
    
    db.close()
    return {
        "revenue_paid": paid,
        "revenue_pending": pending,
        "revenue_rejected": rejected,
        "rejection_rate": round(rejection_rate, 1),
        "total_claims": total_claims
    }
