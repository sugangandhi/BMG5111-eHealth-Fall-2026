import time
import random

def triage_document(filename: str) -> dict:
    """
    Simulates AI classification and extraction based on the uploaded file's name.
    """
    time.sleep(2) # Simulate OCR and LLM processing
    
    filename_lower = filename.lower()
    
    if "card" in filename_lower or "ohip" in filename_lower:
        return {
            "type": "health_card",
            "title": "Ontario Health Card",
            "confidence": 0.98,
            "data": {
                "patient_name": "John Doe",
                "health_card_number": f"{random.randint(1000,9999)}-{random.randint(100,999)}-{random.randint(100,999)}",
                "version_code": random.choice(["AA", "AB", "YM", "ZN"]),
                "dob": "1985-04-12"
            },
            "suggested_action": "Update Patient Profile",
            "action_type": "update_billing"
        }
        
    elif "referral" in filename_lower or "consult" in filename_lower:
        return {
            "type": "referral",
            "title": "Specialist Referral Letter",
            "confidence": 0.94,
            "data": {
                "patient_name": "Sarah Jenkins",
                "referred_to": "Dr. Miller (Cardiology)",
                "reason": "Recurrent palpitations and atypical chest pain.",
                "urgency": "Urgent (Priority 2)",
                "date": "2023-10-15"
            },
            "suggested_action": "Route to Triage Queue",
            "action_type": "route_triage"
        }
        
    elif "lab" in filename_lower or "blood" in filename_lower or "result" in filename_lower:
        return {
            "type": "lab_result",
            "title": "LifeLabs Blood Panel",
            "confidence": 0.99,
            "data": {
                "patient_name": "Michael Chang",
                "collection_date": "2023-10-14",
                "abnormal_flags": 2,
                "findings": [
                    {"test": "Hemoglobin A1C", "value": "7.8%", "flag": "HIGH", "reference": "< 6.0%"},
                    {"test": "LDL Cholesterol", "value": "4.2 mmol/L", "flag": "HIGH", "reference": "< 3.0 mmol/L"}
                ]
            },
            "suggested_action": "Alert Physician & Draft Message",
            "action_type": "alert_physician"
        }
        
    else:
        return {
            "type": "general_document",
            "title": "Unclassified Medical Record",
            "confidence": 0.65,
            "data": {
                "filename": filename,
                "summary": "General clinical document. No specific structured data detected."
            },
            "suggested_action": "Attach to Patient File",
            "action_type": "attach_chart"
        }
