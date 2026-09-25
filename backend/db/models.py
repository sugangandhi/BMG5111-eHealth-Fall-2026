"""
SQLAlchemy models for MedOffice AI.
"""
from datetime import datetime, date
from sqlalchemy import Column, Integer, String, Text, DateTime
from sqlalchemy.orm import declarative_base

Base = declarative_base()

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(String(128), nullable=False)
    full_name = Column(String(100))
    initials = Column(String(10))
    role = Column(String(50))
    clinic = Column(String(100))
    cpso = Column(String(20))

class Appointment(Base):
    __tablename__ = "appointments"
    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), index=True, nullable=False)
    patient_name = Column(String(100), nullable=False)
    initials = Column(String(10), default="")
    time = Column(String(10), nullable=False)
    duration = Column(Integer, default=20)
    type = Column(String(100), nullable=False)
    appointment_date = Column(String(20), index=True, nullable=False)
    status = Column(String(20), default="upcoming")
    color = Column(String(20), default="blue")
    badge = Column(String(50), default="")
    notes = Column(Text, default="")
    created_at = Column(DateTime, default=datetime.utcnow)

class ActivityLog(Base):
    __tablename__ = "activity_log"
    id = Column(Integer, primary_key=True, index=True)
    action = Column(String(50), nullable=False)
    description = Column(String(255), nullable=False)
    patient_name = Column(String(100), default="")
    patient_id = Column(String(50), default="")
    detail = Column(String(255), default="")
    color = Column(String(20), default="teal")
    created_at = Column(DateTime, default=datetime.utcnow)

class FormSubmission(Base):
    __tablename__ = "form_submissions"
    id = Column(Integer, primary_key=True, index=True)
    patient_id = Column(String(50), index=True, nullable=False)
    patient_name = Column(String(100), nullable=False)
    form_type = Column(String(100), default="")
    fields_filled = Column(Integer, default=0)
    fields_total = Column(Integer, default=0)
    submission_date = Column(String(20), default=lambda: date.today().isoformat())
    created_at = Column(DateTime, default=datetime.utcnow)

class Claim(Base):
    __tablename__ = "claims"
    id = Column(Integer, primary_key=True, index=True)
    claim_id = Column(String(50), unique=True, index=True, nullable=False)
    patient_name = Column(String(100), nullable=False)
    health_card_number = Column(String(20), default="")
    version_code = Column(String(5), default="")
    date_of_service = Column(String(20), nullable=False)
    ohip_diagnostic_codes = Column(Text, default="[]") # JSON list of strings
    ohip_fee_codes = Column(Text, default="[]") # JSON list of strings
    revenue = Column(Integer, default=0)
    status = Column(String(50), default="Pending Review") # Pending Review, Submitted to MCEDT, Paid, Rejected
    warnings = Column(Text, default="[]") # JSON list of strings
    created_at = Column(DateTime, default=datetime.utcnow)

class ClaimTemplate(Base):
    __tablename__ = "claim_templates"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False, unique=True)
    ohip_diagnostic_codes = Column(Text, default="[]")
    ohip_fee_codes = Column(Text, default="[]")
    revenue = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
