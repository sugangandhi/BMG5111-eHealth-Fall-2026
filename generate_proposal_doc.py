import docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml import parse_xml
from docx.oxml.ns import nsdecls

def set_cell_margins(cell, top=140, bottom=140, left=180, right=180):
    tcPr = cell._tc.get_or_add_tcPr()
    tcMar = parse_xml(
        f'<w:tcMar {nsdecls("w")}>'
        f'<w:top w:w="{top}" w:type="dxa"/>'
        f'<w:bottom w:w="{bottom}" w:type="dxa"/>'
        f'<w:left w:w="{left}" w:type="dxa"/>'
        f'<w:right w:w="{right}" w:type="dxa"/>'
        f'</w:tcMar>'
    )
    tcPr.append(tcMar)

def set_table_borders(table, color="333333", sz="6", val="single"):
    tblPr = table._tbl.tblPr
    borders = parse_xml(
        f'<w:tblBorders {nsdecls("w")}>'
        f'<w:top w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:bottom w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:left w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:right w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideH w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'<w:insideV w:val="{val}" w:sz="{sz}" w:space="0" w:color="{color}"/>'
        f'</w:tblBorders>'
    )
    tblPr.append(borders)

def build_proposal_doc(filename="Project_Proposal_Group_12_eHealth_Fall_2026.docx"):
    doc = docx.Document()

    # Page setup (Standard Letter, 0.75 in margins)
    for section in doc.sections:
        section.top_margin = Inches(0.75)
        section.bottom_margin = Inches(0.75)
        section.left_margin = Inches(0.8)
        section.right_margin = Inches(0.8)

    # Document Header / Institution Info
    header_p = doc.add_paragraph()
    header_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    h_run1 = header_p.add_run("UNIVERSITÉ D’OTTAWA / UNIVERSITY OF OTTAWA\n")
    h_run1.font.name = "Calibri"
    h_run1.font.size = Pt(11)
    h_run1.font.bold = True
    h_run1.font.color.rgb = RGBColor(143, 17, 44) # uOttawa Garnet

    h_run2 = header_p.add_run("Faculté de Génie · Faculty of Engineering\nBMG 5111 / ELG 6131 / DTI 6302 — eHealth, mHealth & Telemedicine\n")
    h_run2.font.name = "Calibri"
    h_run2.font.size = Pt(10)
    h_run2.font.color.rgb = RGBColor(70, 70, 70)

    title_p = doc.add_paragraph()
    title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    t_run = title_p.add_run("Project Proposal Template fall 2026")
    t_run.font.name = "Calibri"
    t_run.font.size = Pt(15)
    t_run.font.bold = True
    title_p.paragraph_format.space_after = Pt(14)

    # Create Table: 8 rows, 1 column matching the PDF template
    table = doc.add_table(rows=8, cols=1)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    set_table_borders(table, color="222222", sz="6", val="single")

    # Set column width
    for row in table.rows:
        row.cells[0].width = Inches(6.9)
        set_cell_margins(row.cells[0], top=120, bottom=120, left=160, right=160)

    # --- ROW 0: Project Group ID ---
    cell = table.cell(0, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    r_lbl = p.add_run("Project Group ID: ")
    r_lbl.font.bold = True
    r_lbl.font.size = Pt(10.5)
    r_val = p.add_run("Group 12 (Team: Suganthan M. & Collaborator)")
    r_val.font.size = Pt(10.5)

    # --- ROW 1: Project ID ---
    cell = table.cell(1, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    r_lbl = p.add_run("Project ID: ")
    r_lbl.font.bold = True
    r_lbl.font.size = Pt(10.5)
    r_val = p.add_run("Group_12_eHealth_Fall_2026")
    r_val.font.size = Pt(10.5)

    # --- ROW 2: Project Title ---
    cell = table.cell(2, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(2)
    r_lbl = p.add_run("Project Title: ")
    r_lbl.font.bold = True
    r_lbl.font.size = Pt(10.5)
    r_val = p.add_run("e-Hospital AI-Twin: An Agentic Multi-Model Clinical Reasoning Platform with Ambient Voice Scribing, Intelligent EHR Integration, and Patient Digital Twin Visualization")
    r_val.font.bold = True
    r_val.font.size = Pt(10.5)
    r_val.font.color.rgb = RGBColor(15, 23, 42)

    # --- ROW 3: Project Short Description ---
    cell = table.cell(3, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(4)
    r_head = p.add_run("Project Short Description: Problem Definition and Project Overview\n")
    r_head.font.bold = True
    r_head.font.size = Pt(10.5)

    r_prompt = p.add_run(
        "Identify the problem or topic that motivates your project. Explain why the project is important to you or your team "
        "and this class specifically to the eHospital Platform. Specify the potential benefits to others (users) that will result "
        "from the project. Identify the general approach you are going to take to the problem and describe what you hope to learn and/or accomplish.\n"
    )
    r_prompt.font.italic = True
    r_prompt.font.size = Pt(9)
    r_prompt.font.color.rgb = RGBColor(90, 90, 90)

    desc_p1 = cell.add_paragraph()
    desc_p1.paragraph_format.space_after = Pt(4)
    r = desc_p1.add_run("1. Problem Definition & Clinical Motivation:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = desc_p1.add_run(
        "Modern healthcare providers in outpatient clinics and hospital environments face severe administrative and documentation burdens. "
        "Empirical time-motion studies indicate that physicians spend approximately two hours on electronic health record (EHR) data entry and administrative "
        "paperwork for every single hour of direct patient consultation. This documentation tax—often called 'pajama time'—drives widespread clinical burnout, "
        "depletes healthcare capacity, and distracts physicians from high-touch patient interactions. Furthermore, secondary workflows including filling complex "
        "insurance/WSIB/disability forms, managing fragmented specialty referrals, and navigating convoluted provincial billing codes (such as Ontario's OHIP schedule) "
        "suffer from severe delays, transcription errors, and claim rejections. Crucially, conventional EHR databases remain static, retrospective silos that lack "
        "real-time clinical reasoning, guideline compliance auditing, or intuitive physiological visualization for patient-provider shared decision making."
    )
    r.font.size = Pt(9.5)

    desc_p2 = cell.add_paragraph()
    desc_p2.paragraph_format.space_after = Pt(4)
    r = desc_p2.add_run("2. Importance to eHealth & Alignment with the e-Hospital Platform (https://www.e-hospital.ca/):\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = desc_p2.add_run(
        "This project directly aligns with the visionary e-Hospital Platform, which seeks to transform healthcare through state-of-the-art Agentic AI and "
        "AI-driven Digital Twins. Specifically, our proposal addresses the core e-Hospital platform requirements by integrating the specific project subsystems defined by the instructor: "
        "(i) Project Topic #3 (Backend Multi-AI Agents Subsystem): Engineering specialized clinical reasoning agents for diagnostic risk assessment, personalized care plans, clinical scheduling, and back-office paperwork/billing automation; "
        "(ii) Project Topic #6 (AI-Powered Voice-to-Text Conversation): Developing an on-premise ambient speech-to-text clinical scribe that captures doctor-patient dialogues and automatically structures them into the database; and "
        "(iii) Project Topic #4 & Core Digital Twin: Establishing an intelligent FHIR-compliant EHR data pipeline that links structured clinical data directly to an interactive 2D/3D Patient Digital Twin."
    )
    r.font.size = Pt(9.5)

    desc_p3 = cell.add_paragraph()
    desc_p3.paragraph_format.space_after = Pt(4)
    r = desc_p3.add_run("3. Potential Benefits to End-Users & Stakeholders:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = desc_p3.add_run(
        "• Clinicians (Physicians & Nurse Practitioners): Saves 1.5 to 2 hours of daily documentation time via automated ambient SOAP notes, real-time Canadian clinical guideline risk alerts (Hypertension Canada, Diabetes Canada, KDIGO), and instant natural-language chart querying.\n"
        "• Administrative & Medical Office Assistants (MOAs): Automates 70%+ of tedious clinical forms using multi-modal OCR field extraction, eliminates billing rejection risks through deterministic OHIP rule validation, and speeds up inbound inbox triage.\n"
        "• Patients: Experience undivided physician attention, improved safety via automated drug-disease interaction checks, and unprecedented health literacy through interactive 3D digital twin visualizations of their anatomical condition.\n"
        "• Healthcare System: Increases clinic operational throughput, accelerates specialist referral turnaround, and standardizes data exchange using HL7 FHIR standards."
    )
    r.font.size = Pt(9.5)

    desc_p4 = cell.add_paragraph()
    desc_p4.paragraph_format.space_after = Pt(4)
    r = desc_p4.add_run("4. General Engineering Approach & Learning Goals:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = desc_p4.add_run(
        "We propose a modular, full-stack micro-agent architecture. The presentation layer features a responsive React/Vite dashboard integrated with Three.js/WebGL for 3D digital twin visualization. "
        "The asynchronous FastAPI backend coordinates five specialized intelligent agents: (a) an Ambient Voice Scribe utilizing local private LLMs (Ollama / Gemma 2:2B) and speech recognition; "
        "(b) a Canadian Clinical Practice Guideline Risk Scorer; (c) an OCR Document Extraction & Form Filling Agent (powered by Docling & PyMuPDF); (d) an Automated OHIP Billing & Triage Engine; and "
        "(e) a 3D Biomechanical & Physiological Digital Twin pipeline running on synthetic NIfTI/STL volumes. "
        "Our team aims to master healthcare data interoperability (HL7 FHIR R4), multi-agent LLM orchestration, privacy-preserving on-premise AI deployments (PHIPA/PIPEDA compliant), and medical image mesh generation."
    )
    r.font.size = Pt(9.5)

    # --- ROW 4: Project Context and Data Plan ---
    cell = table.cell(4, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(4)
    r_head = p.add_run("Project Context and Data Plan:\n")
    r_head.font.bold = True
    r_head.font.size = Pt(10.5)

    r_prompt = p.add_run(
        "(third party interfaces, APIs, or other third-party tools that will interact with your proposed design, Data you may need):\n"
        "Describe what external systems, subsystems or components you will need to interact with and identify any third-party interfaces, APIs. "
        "Also identify what individuals or organizations (outside of your project team) you will need to interact with to complete your project. "
        "In particular, identify key dependencies in terms of people’s times you will need access to, as well as any resources or information they will provide. "
        "Confirm that they will be available and accessible (describe). What data in specific you may need, do you have access to such data, what is the plan?\n"
    )
    r_prompt.font.italic = True
    r_prompt.font.size = Pt(9)
    r_prompt.font.color.rgb = RGBColor(90, 90, 90)

    ctx_p1 = cell.add_paragraph()
    ctx_p1.paragraph_format.space_after = Pt(4)
    r = ctx_p1.add_run("1. External Systems, Subsystems, and APIs:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = ctx_p1.add_run(
        "• HL7 FHIR Interoperability Standard (Release 4): Implements standardized resource schemas (Patient, Encounter, Observation, Condition, Claim) to guarantee seamless EHR database integration.\n"
        "• WhatsApp Business & Conversational Telemedicine Gateway: Integrates Meta WhatsApp Cloud API / Twilio Webhooks (`/api/whatsapp/webhook`) for asynchronous patient communication. Incoming messages are automatically matched to the patient's EHR profile via verified phone number/DOB, dynamically logging home vitals, symptom reports, and triage chats into the longitudinal medical chart.\n"
        "• Local Privacy-Preserving LLM & Audio Inference: Uses an on-premise Ollama instance (http://localhost:11434/v1) hosting Gemma 2:2B / Llama 3 models and Web Speech API / local Whisper STT. No audio or patient text is transmitted over external public clouds, satisfying strict Canadian health privacy requirements.\n"
        "• Document Understanding & Computer Vision: Integrates Docling (IBM multi-modal document parser), PyMuPDF (fitz), and Tesseract OCR for parsing intake forms, health cards, and overlaying filled coordinates.\n"
        "• Ontario Health Insurance Plan (OHIP) / MCEDT Simulator: Emulates the Medical Claims Electronic Data Transfer interface, utilizing the official Ontario Schedule of Benefits fee codes and diagnostic codes.\n"
        "• WebGL / Three.js 3D Rendering Subsystem: Interfaces with STL/OBJ meshes and synthetic volumetric scans for interactive physiological visualization."
    )
    r.font.size = Pt(9.5)

    ctx_p2 = cell.add_paragraph()
    ctx_p2.paragraph_format.space_after = Pt(4)
    r = ctx_p2.add_run("2. People, Stakeholders, and Collaboration Dependencies:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = ctx_p2.add_run(
        "• Course Instructor & Teaching Assistants (uOttawa Faculty of Engineering): Accessible weekly during office hours and tutorial sessions to review engineering milestones, evaluate architecture, and ensure rubric compliance.\n"
        "• Clinical Advisor / Family Physician Consultations: We have confirmed access to an Ontario-licensed primary care physician who has committed 2 to 3 brief consultation sessions (30 minutes each) to validate the clinical realism of generated SOAP notes, referral checklists, and OHIP billing codes.\n"
        "• Team Division of Labor (2 Students): Student 1 specializes in Backend Architecture, AI Multi-Agent orchestration, Ambient Voice Scribe pipeline, Canadian Guideline Risk Scoring, and OHIP billing rules. Student 2 specializes in Frontend Development (React/Vite), 3D WebGL Digital Twin visualization, Docling OCR form filling integration, and validation testing. Both members will contribute equally (50/50) and present equally across all deliverables."
    )
    r.font.size = Pt(9.5)

    ctx_p3 = cell.add_paragraph()
    ctx_p3.paragraph_format.space_after = Pt(4)
    r = ctx_p3.add_run("3. Data Acquisition, Availability & Privacy Management Plan:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = ctx_p3.add_run(
        "• Synthetic Longitudinal EHR Datasets: To eliminate any risk of Personal Health Information (PHI) exposure and circumvent Research Ethics Board (REB) delays, we utilize open-source Synthea-generated cohorts formatted into FHIR R4 JSON. These include realistic clinical profiles across cardiology, endocrinology, nephrology, and rheumatology.\n"
        "• Volumetric Imaging & Mesh Models: We utilize synthetic 3D MRI phantoms generated algorithmically via NumPy/SciPy/NiBabel (saved as .nii.gz files) and 3D organ surface meshes (.stl), already pre-generated and stored in our local repository.\n"
        "• Official Provincial Billing & Fee Schedules: The complete Ontario MOH Schedule of Facility and Physician Benefits has been extracted and pre-indexed (`backend/ohip_codes.json`), granting instant offline access to fee codes and descriptions.\n"
        "• Standardized Medical Forms: Openly accessible clinical templates including Ontario WSIB Form 8, Specialist Referral forms, and medical certificates are stored locally.\n"
        "• Data Access Confirmation: All necessary datasets, templates, and reference ontologies are already fully synthesized, pre-processed, and accessible in our local workspace repository."
    )
    r.font.size = Pt(9.5)

    # --- ROW 5: Example Application of Proposed Project ---
    cell = table.cell(5, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(4)
    r_head = p.add_run("Example Application of the Proposed Project:\n")
    r_head.font.bold = True
    r_head.font.size = Pt(10.5)

    app_p1 = cell.add_paragraph()
    app_p1.paragraph_format.space_after = Pt(4)
    r = app_p1.add_run("Clinical Scenario: Chronic Multi-Morbidity Follow-up & Acute Exertional Chest Pain Triage\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = app_p1.add_run(
        "To illustrate the practical utility of the platform, consider a routine 15-minute consultation at an outpatient clinic in Ottawa with patient 'Robert Vance' (58-year-old male with Type 2 Diabetes, Stage 2 Hypertension, and new exertional retrosternal discomfort):\n\n"
        "1. Ambient Listening & Capture: Dr. Tremblay opens the e-Hospital web interface on a clinic workstation and clicks 'Start Ambient Listening'. During the visit, Dr. Tremblay conducts a natural dialogue with Robert. Robert reports pressure in his chest when climbing stairs, radiating to his left shoulder. Dr. Tremblay checks his vitals (BP 152/92 mmHg, HR 88 bpm) and reviews his recent HbA1c (8.4%) and eGFR (58 mL/min/1.73m²).\n\n"
        "2. Automated Scribing & SOAP Extraction: Upon stopping the recording, the local Scribe Agent processes the transcript in under 3 seconds, categorizing information into a standard clinical note:\n"
        "   • Subjective: Exertional retrosternal tightness with left shoulder radiation over past 2 weeks; denies rest angina or dyspnea.\n"
        "   • Objective: BP 152/92 mmHg, HR 88 bpm regular rhythm; BMI 29.1 kg/m²; HbA1c 8.4%; eGFR 58 mL/min/1.73m² (CKD Stage 3a).\n"
        "   • Assessment: Uncontrolled Type 2 Diabetes; Poorly controlled Essential Hypertension; Atypical angina / suspected coronary artery disease (CAD).\n"
        "   • Plan: Stat outpatient Cardiology referral; urgent treadmill stress test; titrate Ramipril to 10mg daily; repeat troponin and lipid profile.\n\n"
        "3. Real-Time Guideline Risk Scorer: Concurrently, the Risk Scorer agent cross-references the patient's vitals with Canadian clinical practice guidelines, generating immediate alerts: 'Cardiovascular Risk: HIGH' (Hypertension Canada threshold) and 'Renal/Metabolic Risk: HIGH' (Diabetes Canada target exceeded).\n\n"
        "4. Patient Digital Twin Visualization: On the physician's screen, the 3D Digital Twin highlights Robert's coronary vascular tree and kidneys in flashing amber/red alert states. The physician turns the screen toward Robert, using the 3D visual twin to explain how his uncontrolled blood pressure and diabetes contribute to coronary arterial narrowing, significantly improving patient understanding and therapeutic compliance.\n\n"
        "5. One-Click Document & Referral Generation: Dr. Tremblay clicks 'Generate Specialist Referral'. The Form Filler agent automatically maps Robert's demographics, clinical history, and newly generated SOAP assessment into the official Ontario Specialist Referral PDF with precise coordinate alignment, generating a finalized, signed document ready for fax or electronic transmission in seconds.\n\n"
        "6. Automated OHIP Billing & Claim Staging: The Billing Agent analyzes the clinical encounter and automatically assigns diagnostic code '411 - Ischemic heart disease' and fee codes 'A007 - Intermediate Assessment ($33.70)' and 'K013 - Chronic Disease Management ($49.50)'. It checks cross-billing exclusions, logs total expected revenue ($83.20), and stages the claim for batch MCEDT dispatch without requiring manual billing data entry.\n\n"
        "7. Asynchronous WhatsApp Follow-up & Automated EHR Sync: Post-consultation, the patient receives an automated, plain-language care plan and medication reminder directly on WhatsApp. Three days later, Robert replies on WhatsApp: 'Hi doctor, my BP this morning is 138/86 and my fasting glucose is 6.8 mmol/L.' The WhatsApp Webhook matches Robert's phone number ('613-555-0192') directly to his FHIR profile, extracts the numerical vitals via an NLP parsing agent, automatically logs a new Observation into Robert's longitudinal EHR chart, updates the 3D Digital Twin status from high-risk red to improving amber, and posts an audit event into the clinic's Activity Log—closing the telemedicine loop with zero manual transcription."
    )
    r.font.size = Pt(9.5)

    # --- ROW 6: Tools (Hardware and Software needed) ---
    cell = table.cell(6, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(4)
    r_head = p.add_run("Tools (Hardware and Software needed for the project / needed to build a prototype):\n")
    r_head.font.bold = True
    r_head.font.size = Pt(10.5)

    r_prompt = p.add_run(
        "Identify the relevant technologies, papers, textbooks, tools (with references) that you have already investigated "
        "or will need to learn in order to understand the problem and complete the project. tools or systems you will need to use as part of the project\n"
    )
    r_prompt.font.italic = True
    r_prompt.font.size = Pt(9)
    r_prompt.font.color.rgb = RGBColor(90, 90, 90)

    tool_p1 = cell.add_paragraph()
    tool_p1.paragraph_format.space_after = Pt(4)
    r = tool_p1.add_run("1. Software Stack, Libraries & Development Environments:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = tool_p1.add_run(
        "• Backend & API Services: Python 3.11, FastAPI (asynchronous ASGI framework), Uvicorn, SQLAlchemy ORM, SQLite database engine, Pydantic v2 data validation, Python-JOSE (JWT token authentication), Meta WhatsApp Cloud API / Twilio Messaging Webhooks.\n"
        "• AI Agents & Natural Language Processing: Local Ollama runtime (hosting Gemma 2:2B and Llama 3 models), OpenAI Python SDK, Web Speech API / local Whisper STT, Prompt Engineering and structured JSON schema enforcement.\n"
        "• Medical Document OCR & Imaging: Docling (IBM multimodal parser), PyMuPDF (fitz), ReportLab (PDF canvas coordinate overlay), Tesseract OCR, NiBabel (NIfTI-1 medical image I/O), NumPy, SciPy (multidimensional image processing), PyVista/VTK.\n"
        "• Frontend & 3D Visualization: React 18, Vite, Tailwind CSS, Lucide React icons, Framer Motion, Axios, Three.js / WebGL for interactive 3D anatomical mesh rendering.\n"
        "• Clinical Standards & Schemas: HL7 FHIR R4 Specification, Ontario Ministry of Health Schedule of Benefits, Synthea Synthetic Healthcare Generator."
    )
    r.font.size = Pt(9.5)

    tool_p2 = cell.add_paragraph()
    tool_p2.paragraph_format.space_after = Pt(4)
    r = tool_p2.add_run("2. Hardware Infrastructure:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = tool_p2.add_run(
        "• Workstation Compute: Standard consumer laptops and development workstations equipped with modern multi-core processors (Intel Core i7 / AMD Ryzen / Apple M-series), 16GB+ RAM, and hardware GPU acceleration (NVIDIA RTX / Metal) capable of running quantized local LLMs at >15 tokens/sec with sub-second response times.\n"
        "• Audio Recording: Standard built-in laptop microphones and external USB cardioid microphones for acoustic voice capture."
    )
    r.font.size = Pt(9.5)

    tool_p3 = cell.add_paragraph()
    tool_p3.paragraph_format.space_after = Pt(4)
    r = tool_p3.add_run("3. Academic Papers, Textbooks & Clinical References (IEEE Format):\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = tool_p3.add_run(
        "[1] E. H. Shortliffe and J. J. Cimino, Eds., Biomedical Informatics: Computer Applications in Health Care and Biomedicine, 5th ed. Cham, Switzerland: Springer Nature, 2021.\n"
        "[2] C. A. Sinsky et al., 'Allocation of physician time in ambulatory practice: A time and motion study in 4 specialties,' Annals of Internal Medicine, vol. 165, no. 11, pp. 753–760, 2016.\n"
        "[3] A. Rajkomar, J. Dean, and I. Kohane, 'Machine learning in medicine,' New England Journal of Medicine, vol. 380, no. 14, pp. 1347–1358, 2019.\n"
        "[4] E. Coiera, Guide to Health Informatics, 3rd ed. Boca Raton, FL: CRC Press, 2015.\n"
        "[5] Health Level Seven International, 'HL7 Fast Healthcare Interoperability Resources (FHIR) Release 4,' HL7.org, 2019. [Online]. Available: https://hl7.org/fhir/R4/\n"
        "[6] Ontario Ministry of Health, 'Schedule of Facility and Physician Benefits for Medical Claims (OHIP),' Queen's Printer for Ontario, Toronto, ON, 2025/2026.\n"
        "[7] Hypertension Canada, 'Comprehensive Clinical Practice Guidelines for the Management of Hypertension in Adults,' Canadian Journal of Cardiology, vol. 36, no. 5, pp. 596–624, 2024.\n"
        "[8] Diabetes Canada Clinical Practice Guidelines Expert Committee, 'Pharmacologic Glycemic Management of Type 2 Diabetes in Adults,' Canadian Journal of Diabetes, vol. 47, no. 1, pp. 54–75, 2023."
    )
    r.font.size = Pt(9)

    # --- ROW 7: Project Notes ---
    cell = table.cell(7, 0)
    p = cell.paragraphs[0]
    p.paragraph_format.space_after = Pt(4)
    r_head = p.add_run("Project Notes: (You may add any additional information if you have or any references…etc.)\n")
    r_head.font.bold = True
    r_head.font.size = Pt(10.5)

    note_p1 = cell.add_paragraph()
    note_p1.paragraph_format.space_after = Pt(4)
    r = note_p1.add_run("1. Course Deliverable Timeline & Milestone Mapping:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = note_p1.add_run(
        "Our engineering roadmap is structured to meet all BMG5111 / ELG6131 / DTI6302 milestone requirements:\n"
        "• Milestone 1 (Sept 16, 2026): Project Proposal Submission [Current Deliverable].\n"
        "• Milestone 2 (Sept 30, 2026): Detailed Architectural Design, Component Decomposition, Data Flow Architecture, and Literature Review.\n"
        "• Milestone 3 (Nov 4, 2026 - 20%): System Implementation Methodology & Midterm Presentation of Proof-of-Concept / Minimum Viable Prototype (MVP) featuring the live ambient scribe, FHIR EHR queries, and preliminary 2D/3D digital twin.\n"
        "• Milestone 4 (Dec 2, 2026 - 10%): Project Final Presentation & Live Demonstration featuring the full multi-agent suite, automated form filling, and interactive 3D digital twin.\n"
        "• Milestone 5 (Dec 15, 2026 - 40%): Project Final Comprehensive Report in IEEE paper format (submitted in MS Word .docx format)."
    )
    r.font.size = Pt(9.5)

    note_p2 = cell.add_paragraph()
    note_p2.paragraph_format.space_after = Pt(4)
    r = note_p2.add_run("2. Regulatory, Privacy & Ethical Compliance (PHIPA & PIPEDA):\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = note_p2.add_run(
        "A critical engineering requirement in healthcare is strict data sovereignty and patient confidentiality. The architecture operates under a "
        "'Privacy by Design' model: all speech recognition and LLM inference run entirely on the local machine via Ollama, preventing any third-party cloud data leakage. "
        "Furthermore, by using 100% synthetic FHIR patient datasets and synthetic 3D phantoms, the project adheres fully to Ontario's Personal Health Information Protection Act (PHIPA) "
        "and federal PIPEDA guidelines without requiring lengthy Research Ethics Board (REB) approval, allowing our team to focus directly on engineering innovation."
    )
    r.font.size = Pt(9.5)

    note_p3 = cell.add_paragraph()
    note_p3.paragraph_format.space_after = Pt(2)
    r = note_p3.add_run("3. Existing Codebase & Project Feasibility:\n")
    r.font.bold = True
    r.font.size = Pt(9.5)
    r = note_p3.add_run(
        "Our team has already established the foundational prototype repository (`Hackers-Healers-1`), containing the operational FastAPI backend, "
        "React/Vite dashboard, synthetic FHIR data loader, Docling OCR form parser, and initial 3D mesh processing routines. This existing foundation eliminates "
        "initial setup friction and guarantees our team will deliver a robust, highly functional MVP by the November 4 midterm deadline and an impressive live demo on December 2."
    )
    r.font.size = Pt(9.5)

    try:
        doc.save(filename)
        print(f"Successfully generated proposal document: {filename}")
    except PermissionError:
        fallback = filename.replace(".docx", "_v2.docx")
        doc.save(fallback)
        print(f"File '{filename}' was locked (likely open in Word). Saved updated version to: {fallback}")

if __name__ == "__main__":
    build_proposal_doc()
