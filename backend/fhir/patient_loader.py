"""
Loads and queries synthetic FHIR patient data.
In production this would be replaced with a real FHIR server query.
"""
import json
from pathlib import Path
from typing import Optional

_DATA_PATH = Path(__file__).parent / "patients.json"
_patients: Optional[list[dict]] = None


def _load() -> list[dict]:
    global _patients
    if _patients is None:
        with open(_DATA_PATH, encoding="utf-8") as f:
            _patients = json.load(f)["patients"]
    return _patients


def list_patients() -> list[dict]:
    return [
        {
            "id": p["id"],
            "name": p["name"]["text"],
            "birthDate": p["birthDate"],
            "phone": p.get("phone", "613-555-0192"),
            "allergies": ", ".join(p.get("allergies", [])) if isinstance(p.get("allergies"), list) else (p.get("allergies") or "NKDA"),
            "mrn": p.get("ohip", f"MRN-{p['id']}"),
            "gender": p.get("gender", "")
        }
        for p in _load()
    ]


def get_patient(patient_id: str) -> Optional[dict]:
    for p in _load():
        if p["id"] == patient_id:
            return p
    return None


def update_patient_phone(patient_id: str, new_phone: str) -> Optional[dict]:
    global _patients
    clean_phone = new_phone.strip()
    patients = _load()
    target = None
    for p in patients:
        if p["id"] == patient_id:
            p["phone"] = clean_phone
            target = p
            break
    if target:
        try:
            with open(_DATA_PATH, "w", encoding="utf-8") as f:
                json.dump({"patients": patients}, f, indent=2)
        except Exception as e:
            print(f"[PatientLoader] Error persisting patient phone: {e}")
    return target


def build_patient_context(patient_id: str) -> str:
    """
    Returns a rich plain-text summary of the patient record formatted for the LLM.
    Structured to make field mapping straightforward for any form type.
    """
    p = get_patient(patient_id)
    if not p:
        return ""

    lines = [
        "=== PATIENT RECORD ===",
        f"Name: {p['name']['text']}",
        f"  Family name: {p['name'].get('family', '')}",
        f"  Given names: {' '.join(p['name'].get('given', []))}",
        f"Date of birth: {p['birthDate']}",
        f"Gender: {p['gender']}",
        f"OHIP: {p.get('ohip', 'N/A')}",
        f"Social Insurance Number (SIN): {p.get('sin', 'Not on file')}",
        f"Preferred language: {p.get('language', 'English')}",
        f"Address: {p['address']['line'][0]}, {p['address']['city']}, {p['address']['province']} {p['address']['postalCode']}",
        f"Phone: {p.get('phone', 'N/A')}",
    ]

    if p.get("guardian"):
        g = p["guardian"]
        lines.append(f"Guardian/Parent: {g['name']} ({g['relationship']}) — {g['phone']}")

    # Social history
    if p.get("social_history"):
        sh = p["social_history"]
        lines += ["", "--- SOCIAL HISTORY ---"]
        for k, v in sh.items():
            lines.append(f"  {k.replace('_', ' ').title()}: {v}")

    # Family history
    if p.get("family_history"):
        lines += ["", "--- FAMILY HISTORY ---"]
        for item in p["family_history"]:
            lines.append(f"  • {item}")

    # Conditions
    lines += ["", "--- ACTIVE CONDITIONS / DIAGNOSES ---"]
    for c in p.get("conditions", []):
        work = " [WORK-RELATED]" if c.get("workRelated") else ""
        status = f" ({c['status']})" if c.get("status") != "active" else ""
        lines.append(f"  • {c['display']} (ICD-10: {c['code']}) — onset {c['onsetDate']}{work}{status}")
        if c.get("workInjuryDetails"):
            lines.append(f"    Injury details: {c['workInjuryDetails']}")
        if c.get("notes"):
            lines.append(f"    Notes: {c['notes']}")
        if c.get("gestational_age"):
            lines.append(f"    Gestational age: {c['gestational_age']}")

    # Medications
    lines += ["", "--- CURRENT MEDICATIONS ---"]
    for m in p.get("medications", []):
        line = f"  • {m['name']} {m['dose']} {m['frequency']} (DIN: {m.get('din','?')}, since {m['startDate']})"
        if m.get("indication"):
            line += f" — for {m['indication']}"
        lines.append(line)
        if m.get("monitoring"):
            lines.append(f"    Monitoring: {m['monitoring']}")

    lines.append(f"\nAllergies: {', '.join(p.get('allergies', ['NKDA']))}")
    if p.get("epipen"):
        lines.append(f"EpiPen: {p['epipen']}")

    # Lab results
    if p.get("labs"):
        lines += ["", "--- RECENT LAB RESULTS ---"]
        for lab in p["labs"]:
            flag = f" ← {lab['flag']}" if lab.get("flag") and lab["flag"] != "NORMAL" else ""
            ref  = f" (ref: {lab['reference']})" if lab.get("reference") else ""
            lines.append(f"  • {lab['date']} | {lab['test']}: {lab['value']} {lab.get('unit','')}{ref}{flag}")

    # Vital signs
    if p.get("vitals_trend"):
        lines += ["", "--- VITAL SIGNS ---"]
        for v in p["vitals_trend"][:3]:
            parts = [f"BP {v['bp']}", f"HR {v['hr']}", f"Wt {v['weight']}", f"BMI {v['bmi']}"]
            if v.get("o2_sat"):
                parts.append(f"SpO2 {v['o2_sat']}")
            if v.get("peak_flow"):
                parts.append(f"Peak flow {v['peak_flow']}")
            if v.get("fundal_height"):
                parts.append(f"Fundal ht {v['fundal_height']}")
            lines.append(f"  • {v['date']} | {', '.join(parts)}")

    # Imaging
    if p.get("imaging"):
        lines += ["", "--- IMAGING / INVESTIGATIONS ---"]
        for img in p["imaging"]:
            lines.append(f"  • {img['date']} | {img['type']}")
            lines.append(f"    Result: {img['result']}")

    # Specialist notes
    if p.get("specialist_notes"):
        lines += ["", "--- SPECIALIST CONSULTATIONS ---"]
        for note in p["specialist_notes"]:
            lines.append(f"  • {note['date']} | {note['specialty']} — {note['physician']}")
            lines.append(f"    {note['summary']}")

    # Functional / disability status
    if p.get("functional_status"):
        fs = p["functional_status"]
        lines += ["", "--- FUNCTIONAL STATUS / DISABILITY ---"]
        if fs.get("off_work_since"):
            lines.append(f"  Off work since: {fs['off_work_since']}")
        if fs.get("reason"):
            lines.append(f"  Reason: {fs['reason']}")
        if fs.get("expected_rtw"):
            lines.append(f"  Expected return to work: {fs['expected_rtw']}")
        if fs.get("restrictions"):
            lines.append(f"  Restrictions: {fs['restrictions']}")

    # Vaccinations
    if p.get("vaccinations"):
        lines += ["", "--- VACCINATIONS ---"]
        for v in p["vaccinations"]:
            note = f" ({v['notes']})" if v.get("notes") else ""
            lines.append(f"  • {v['vaccine']} — {v['date']}{note}")

    # Preventive screening
    if p.get("screening"):
        lines += ["", "--- PREVENTIVE SCREENING ---"]
        for s in p["screening"]:
            lines.append(f"  • {s['type']} ({s['date']}): {s['result']}")

    # Encounters
    lines += ["", "--- RECENT ENCOUNTERS ---"]
    for e in p.get("encounters", []):
        lines.append(f"  • {e['date']} | {e['type']} | {e['reason']}")
        if e.get("notes"):
            lines.append(f"    Notes: {e['notes']}")

    # Employer
    if p.get("employer"):
        emp = p["employer"]
        lines += ["", "--- EMPLOYER ---"]
        lines.append(f"  Name: {emp['name']}")
        lines.append(f"  Address: {emp['address']}")
        lines.append(f"  Phone: {emp['phone']}")
        if emp.get("supervisor"):
            lines.append(f"  Supervisor: {emp['supervisor']}")

    # School info (paediatric)
    if p.get("school_info"):
        si = p["school_info"]
        lines += ["", "--- SCHOOL INFORMATION ---"]
        lines.append(f"  School: {si['school']}")
        lines.append(f"  Grade: {si['grade']}")
        lines.append(f"  Principal: {si['principal']}")
        lines.append(f"  Address: {si['address']}")
        lines.append(f"  Phone: {si['phone']}")

    # WSIB / clinical assessment
    if p.get("clinical_assessment"):
        ca = p["clinical_assessment"]
        lines += ["", "--- CLINICAL ASSESSMENT ---"]
        if ca.get("pain_at_rest"):       lines.append(f"  Pain at rest: {ca['pain_at_rest']}")
        if ca.get("pain_with_activity"): lines.append(f"  Pain with activity: {ca['pain_with_activity']}")
        if ca.get("pain_at_night"):      lines.append(f"  Pain at night: {ca['pain_at_night']}")
        if ca.get("area_of_injury"):     lines.append(f"  Area of injury: {ca['area_of_injury']} ({ca.get('body_side','')})")
        if ca.get("injury_type"):        lines.append(f"  Injury type: {ca['injury_type']}")
        if ca.get("physical_exam"):      lines.append(f"  Physical exam: {ca['physical_exam']}")
        if ca.get("diagnosis_description"): lines.append(f"  Diagnosis: {ca['diagnosis_description']}")
        if ca.get("pre_existing_conditions"): lines.append(f"  Pre-existing conditions: {ca['pre_existing_conditions']}")

    # RTW plan
    if p.get("rtw_plan"):
        rtw = p["rtw_plan"]
        lines += ["", "--- RETURN TO WORK (RTW) PLAN ---"]
        lines.append(f"  RTW discussed with patient: {'Yes' if rtw.get('rtw_discussed_with_patient') else 'No'}")
        lines.append(f"  Regular duties possible: {'Yes' if rtw.get('regular_duties_possible') else 'No'}")
        lines.append(f"  Modified duties possible: {'Yes' if rtw.get('modified_duties_possible') else 'No'}")
        if rtw.get("modified_duties_start_date"): lines.append(f"  Modified duties start date: {rtw['modified_duties_start_date']}")
        if rtw.get("graduated_hours_required") is not None: lines.append(f"  Graduated hours required: {'Yes' if rtw['graduated_hours_required'] else 'No'}")
        if rtw.get("unable_to_work") is not None and rtw["unable_to_work"]: lines.append("  Worker is NOT able to work")
        if rtw.get("limitations_duration"): lines.append(f"  Limitations duration: {rtw['limitations_duration']}")
        if rtw.get("follow_up_date"):     lines.append(f"  Follow-up appointment date: {rtw['follow_up_date']}")
        if rtw.get("functional_abilities"):
            fa = rtw["functional_abilities"]
            if fa.get("able_to"):     lines.append(f"  ABLE TO: {', '.join(fa['able_to'])}")
            if fa.get("not_able_to"): lines.append(f"  NOT ABLE TO: {', '.join(fa['not_able_to'])}")
            if fa.get("other_limitations"): lines.append(f"  Other limitations: {fa['other_limitations']}")

    # RA functional assessment
    if p.get("functional_assessment_ra"):
        fa = p["functional_assessment_ra"]
        lines += ["", "--- FUNCTIONAL ASSESSMENT (RA) ---"]
        for k, v in fa.items():
            if k in ("able_to", "not_able_to") and isinstance(v, list):
                lines.append(f"  {k.replace('_',' ').title()}: {', '.join(v)}")
            elif isinstance(v, str):
                lines.append(f"  {k.replace('_',' ').title()}: {v}")

    # Prenatal details
    if p.get("prenatal_details"):
        pd = p["prenatal_details"]
        lines += ["", "--- PRENATAL DETAILS ---"]
        for k, v in pd.items():
            lines.append(f"  {k.replace('_',' ').title()}: {v}")

    # School medical plan
    if p.get("school_medical_plan"):
        smp = p["school_medical_plan"]
        lines += ["", "--- SCHOOL MEDICAL / ANAPHYLAXIS PLAN ---"]
        if smp.get("diagnoses_for_school"): lines.append(f"  Diagnoses: {', '.join(smp['diagnoses_for_school'])}")
        if smp.get("triggers"):             lines.append(f"  Triggers: {smp['triggers']}")
        if smp.get("gym_restrictions"):     lines.append(f"  Gym restrictions: {smp['gym_restrictions']}")
        if smp.get("food_restrictions"):    lines.append(f"  Food restrictions: {smp['food_restrictions']}")
        if smp.get("anaphylaxis_signs"):    lines.append(f"  Anaphylaxis signs: {smp['anaphylaxis_signs']}")
        if smp.get("after_epinephrine"):    lines.append(f"  After epinephrine: {smp['after_epinephrine']}")
        if smp.get("peak_flow_action"):     lines.append(f"  Peak flow zones: {smp['peak_flow_action']}")
        for med in smp.get("emergency_medications_at_school", []):
            lines.append(f"  Emergency med: {med['name']} — {med['instructions']}")
        if smp.get("follow_up"):            lines.append(f"  Plan review: {smp['follow_up']}")

    # Disability claim
    if p.get("disability_claim"):
        dc = p["disability_claim"]
        lines += ["", "--- DISABILITY CLAIM INFO ---"]
        for k, v in dc.items():
            lines.append(f"  {k.replace('_',' ').title()}: {v}")

    # Referrals (structured list)
    if p.get("referrals"):
        lines += ["", "--- REFERRALS ---"]
        for r in p["referrals"]:
            line = f"  • {r['type']}"
            if r.get("facility"):          line += f" — {r['facility']}"
            if r.get("phone"):             line += f", {r['phone']}"
            if r.get("appointment_date"):  line += f", appt {r['appointment_date']}"
            if r.get("reason"):            line += f" (reason: {r['reason']})"
            lines.append(line)

    # Physician (with billing info)
    if p.get("physician"):
        dr = p["physician"]
        lines += [
            "",
            "--- ATTENDING PHYSICIAN ---",
            f"  Name: {dr['name']} | CPSO: {dr['cpso']}",
            f"  Clinic: {dr['clinic']}",
            f"  Address: {dr['address']}",
            f"  Phone: {dr['phone']} | Fax: {dr['fax']}",
        ]
        if dr.get("wsib_provider_id"):   lines.append(f"  WSIB Provider ID: {dr['wsib_provider_id']}")
        if dr.get("hst_registration"):   lines.append(f"  HST Registration No.: {dr['hst_registration']}")
        if dr.get("service_code_form8"): lines.append(f"  WSIB Service Code (Form 8): {dr['service_code_form8']}")

    return "\n".join(lines)
