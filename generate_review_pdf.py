import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, KeepTogether, PageBreak
)
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        self.saveState()
        # Top banner line (page > 1)
        if self._pageNumber > 1:
            self.setFont("Helvetica-Bold", 8)
            self.setFillColor(colors.HexColor("#1e293b"))
            self.drawString(40, 11 * 72 - 30, "eHOSPITAL MOBILE APP CODEBASE REVIEW & PROFESSOR MEETING BRIEF")
            self.setFont("Helvetica", 8)
            self.setFillColor(colors.HexColor("#64748b"))
            self.drawRightString(8.5 * 72 - 40, 11 * 72 - 30, "University of Ottawa | DTI 6302 / BMG 5111")
            self.setStrokeColor(colors.HexColor("#cbd5e1"))
            self.setLineWidth(0.6)
            self.line(40, 11 * 72 - 34, 8.5 * 72 - 40, 11 * 72 - 34)

        # Footer
        self.setStrokeColor(colors.HexColor("#cbd5e1"))
        self.setLineWidth(0.6)
        self.line(40, 38, 8.5 * 72 - 40, 38)

        self.setFont("Helvetica-Bold", 8)
        self.setFillColor(colors.HexColor("#0284c7"))
        self.drawString(40, 26, "Group 12: e-Hospital AI-Twin")
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.HexColor("#64748b"))
        self.drawString(180, 26, "Meeting Notes — Oct 16, 2026 (8:00 PM EST)")

        page_str = f"Page {self._pageNumber} of {page_count}"
        self.drawRightString(8.5 * 72 - 40, 26, page_str)
        self.restoreState()

def build_pdf(filename="eHospital_Mobile_App_Review_Notes.pdf"):
    doc = SimpleDocTemplate(
        filename,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=42,
        bottomMargin=46
    )

    styles = getSampleStyleSheet()

    # Custom palette
    PRIMARY = colors.HexColor("#0f172a")     # Slate 900
    SECONDARY = colors.HexColor("#1e40af")   # Blue 800
    ACCENT_CYAN = colors.HexColor("#0284c7") # Sky 600
    BG_LIGHT = colors.HexColor("#f8fafc")    # Slate 50
    TEXT_DARK = colors.HexColor("#334155")   # Slate 700
    ALERT_RED = colors.HexColor("#dc2626")   # Red 600
    ALERT_BG = colors.HexColor("#fef2f2")    # Red 50

    # Typography styles
    style_header_title = ParagraphStyle(
        'HeaderTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=17,
        leading=21,
        textColor=PRIMARY
    )
    style_header_sub = ParagraphStyle(
        'HeaderSub',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=13.5,
        textColor=SECONDARY
    )
    style_h1 = ParagraphStyle(
        'Heading1_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=15,
        textColor=SECONDARY,
        spaceAfter=5,
        spaceBefore=8,
        keepWithNext=True
    )
    style_h2 = ParagraphStyle(
        'Heading2_Custom',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=10,
        leading=13,
        textColor=PRIMARY,
        spaceAfter=3,
        spaceBefore=5,
        keepWithNext=True
    )
    style_body = ParagraphStyle(
        'Body_Custom',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.5,
        leading=12,
        textColor=TEXT_DARK,
        spaceAfter=4
    )
    style_bullet = ParagraphStyle(
        'Bullet_Custom',
        parent=style_body,
        leftIndent=12,
        firstLineIndent=-8,
        spaceAfter=3
    )
    style_table_text = ParagraphStyle(
        'TableText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=TEXT_DARK
    )
    style_table_header = ParagraphStyle(
        'TableHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11.5,
        textColor=colors.white
    )
    style_box_text = ParagraphStyle(
        'BoxText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8.2,
        leading=11.5,
        textColor=TEXT_DARK
    )

    story = []

    # ==================== PAGE 1 ====================
    # 1. Header Hero Card
    hero_data = [
        [
            Paragraph("<b>UNIVERSITY OF OTTAWA — FACULTY OF ENGINEERING</b><br/>"
                      "<b>Course:</b> BMG 5111 / ELG 6131 / DTI 6302 — eHealth, mHealth & Telemedicine<br/>"
                      "<b>Student/Team:</b> Suganthan M. & Collaborator (Group 12 — <i>Hackers-Healers-1</i>)<br/>"
                      "<b>Meeting Purpose:</b> Pre-Meeting Technical Audit of Downloaded Mobile App Codebase<br/>"
                      "<b>Meeting Time:</b> Today, October 16, 2026 @ 8:00 PM EST", style_header_sub)
        ]
    ]
    hero_table = Table(hero_data, colWidths=[532])
    hero_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), colors.HexColor("#f1f5f9")),
        ('BOX', (0,0), (-1,-1), 1, colors.HexColor("#cbd5e1")),
        ('TOPPADDING', (0,0), (-1,-1), 6),
        ('BOTTOMPADDING', (0,0), (-1,-1), 6),
        ('LEFTPADDING', (0,0), (-1,-1), 10),
        ('RIGHTPADDING', (0,0), (-1,-1), 10),
    ]))
    story.append(hero_table)
    story.append(Spacer(1, 6))

    story.append(Paragraph("e-Hospital Mobile App Review & Strategy Brief", style_header_title))
    story.append(Paragraph("Technical Evaluation of the Summer 2026 Flutter/FastAPI App & High-Yield Questions for Tonight's 8:00 PM Meeting", style_header_sub))
    story.append(Spacer(1, 6))

    # SECTION 1: IDENTIFICATION & EXECUTIVE SUMMARY
    story.append(Paragraph("1. Codebase Identification & Executive Summary", style_h1))
    summary_text = (
        "<b>Downloaded Repository:</b> <code>2026-summer-11-AI-automated-queries-based-on-the-db-schema-and-do-analysis-with-UI-main</code><br/>"
        "<b>Origin & Author:</b> Developed by Yuyang Wei (Student #300484288) for the Summer 2026 cohort of DTI 6302. "
        "It refactors and expands an earlier Winter 2026 project (<code>2026-winter-Unified-Data-Analysis-System...</code>).<br/>"
        "<b>What the System Is:</b> A hybrid patient-facing mobile solution comprising a <b>Flutter mobile client</b> (targeting iOS/HealthKit) "
        "and a companion <b>Python FastAPI AI backend</b> that orchestrates patient queries, LangGraph-style LLM workflows (Ollama / Gemini), "
        "medical report OCR parsing, and integrates with the course's shared AWS App Runner database (<code>https://aetab8pjmb.us-east-1.awsapprunner.com</code>)."
    )
    story.append(Paragraph(summary_text, style_body))
    story.append(Spacer(1, 4))

    # SECTION 2: ARCHITECTURAL DECOMPOSITION
    story.append(Paragraph("2. System Architecture & Component Mapping", style_h1))
    arch_data = [
        [Paragraph("Layer", style_table_header), Paragraph("Component & Tech Stack", style_table_header), Paragraph("Key Responsibilities & Data Handlers", style_table_header)],
        [
            Paragraph("<b>Mobile App</b><br/>(Client)", style_table_text),
            Paragraph("<b>Flutter (Dart)</b><br/>• Material 3<br/>• HealthKit Native Bridge<br/>• fl_chart & SharedPreferences", style_table_text),
            Paragraph("• Patient authentication & session persistence.<br/>• Apple Watch vitals ingestion (Heart Rate, Blood Pressure, Steps, Sleep).<br/>• Patient AI assistant chat & urgent care check-in UI.<br/>• Local notifications for blood pressure adherence alerts.", style_table_text)
        ],
        [
            Paragraph("<b>AI Backend</b><br/>(Microservice)", style_table_text),
            Paragraph("<b>FastAPI (Python)</b><br/>• Port 8000 (<code>src.backend.main:app</code>)<br/>• LangChain / LangGraph<br/>• Tesseract OCR & Poppler", style_table_text),
            Paragraph("• Aggregates patient longitudinal context from AWS MySQL.<br/>• Multi-turn AI chat orchestration (Ollama <code>gemma2:2b</code> / Gemini).<br/>• Document parsing: OCR for lab reports, scanned PDFs, images.<br/>• Alert triage service (3-hour sustained hypertension window).", style_table_text)
        ],
        [
            Paragraph("<b>Cloud DB</b><br/>(Shared Core)", style_table_text),
            Paragraph("<b>AWS App Runner MySQL</b><br/>• 69 Relational Tables<br/>• REST Table & SQL Endpoints", style_table_text),
            Paragraph("• Stores patient demographics (<code>patients_registration</code>), vitals history, ECG, lab results, and diagnostic predictions (diabetes, stroke, heart disease).<br/>• Accessible via <code>GET /table/{table}</code> and <code>POST /sql/select</code>.", style_table_text)
        ]
    ]
    arch_table = Table(arch_data, colWidths=[75, 155, 302])
    arch_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('TOPPADDING', (0,0), (-1,-1), 3.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, BG_LIGHT])
    ]))
    story.append(arch_table)
    story.append(Spacer(1, 5))

    # SECTION 3: KEY MODULES BREAKDOWN
    story.append(Paragraph("3. Deep-Dive: Core Features Implemented", style_h1))
    story.append(Paragraph("• <b>Authentication & Session:</b> Authenticates against eHospital user tables via <code>/login</code>. Supports multiple roles (<code>Patient</code>, <code>Doctor</code>, <code>Clinic</code>, <code>Admin</code>). Stores active <code>patient_id</code> in SharedPreferences.", style_bullet))
    story.append(Paragraph("• <b>Wearable Vitals Sync:</b> Bridges native Apple HealthKit events into Flutter for resting heart rate, active calories, sleep intervals, and systolic/diastolic blood pressure.", style_bullet))
    story.append(Paragraph("• <b>HealthKit Alert Engine:</b> Analyzes blood pressure across a 3-hour moving window. Evaluates patient baseline and active antihypertensive medication context before triggering supportive local push notifications.", style_bullet))
    story.append(Paragraph("• <b>Medical Report Interpreter:</b> Upload pipeline for text, JSON, PDFs, and scanned photos. Uses Tesseract OCR and PyPDF to extract biomarker values and translate abnormal results into plain patient language.", style_bullet))
    story.append(Paragraph("• <b>Urgent Care & Clinic Workflow:</b> Ambulatory check-in module calculating estimated wait times, collecting patient feedback, and maintaining a clinical queue status.", style_bullet))

    story.append(PageBreak())

    # ==================== PAGE 2 ====================
    # SECTION 4: BUGS & TECHNICAL AUDIT
    story.append(Paragraph("4. Critical Codebase Bugs, Bottlenecks & Audit Findings", style_h1))
    
    # Alert Box for the Missing File Bug
    bug_data = [
        [
            Paragraph("<b>CRITICAL BUG FOUND — Backend Startup Crash:</b><br/>"
                      "In <code>src/backend/api/assistant.py</code> (line 24):<br/>"
                      "<code>from src.backend.services.assistant.workflows.health_alert_analysis import analyze_health_alert_event</code><br/>"
                      "The file <code>health_alert_analysis.py</code> is <b>completely missing</b> from the downloaded repository! "
                      "Starting the backend raises an immediate <code>ModuleNotFoundError</code>. This must be shimmed or recovered from an unmerged branch.", style_box_text)
        ]
    ]
    bug_table = Table(bug_data, colWidths=[532])
    bug_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), ALERT_BG),
        ('BOX', (0,0), (-1,-1), 1.2, ALERT_RED),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 8),
        ('RIGHTPADDING', (0,0), (-1,-1), 8),
    ]))
    story.append(bug_table)
    story.append(Spacer(1, 4))

    story.append(Paragraph("<b>Additional Architectural Weaknesses Discovered:</b>", style_h2))
    story.append(Paragraph("• <b>N+1 Serial HTTP Queries & In-Memory Filtering:</b> In <code>patient_context_service.py</code>, building patient context executes <b>10 sequential HTTP requests</b> to AWS App Runner. Crucially, it hits <code>/table/{table}</code> without server-side filtering—downloading entire database tables into Python memory and filtering by <code>patient_id</code> client-side. This creates severe 3–8 second latency bottlenecks.", style_bullet))
    story.append(Paragraph("• <b>Synchronous LLM Blocking:</b> In <code>model_client.py</code>, <code>_build_chat_model().invoke(...)</code> is synchronous and invoked directly within async FastAPI routes, freezing the server event loop during LLM token generation.", style_bullet))
    story.append(Paragraph("• <b>iOS-Only HealthKit Implementation (Android Gap):</b> The native sensor observer queries are written entirely in Swift (<code>AppDelegate.swift</code>, 740+ lines). The Android folder contains only the empty default Flutter template with <b>zero Health Connect or Wear OS support</b>.", style_bullet))
    story.append(Paragraph("• <b>Native Binary Dependencies:</b> Medical Report OCR strictly requires local host installation of C++ system binaries (<code>tesseract-ocr</code> and <code>poppler-utils</code>), complicating deployment.", style_bullet))
    story.append(Paragraph("• <b>Unsecured Cloud Endpoints & Storage:</b> The AWS App Runner eHospital database has no bearer token / API key requirement, allowing unauthenticated read/write access to all 69 tables. Flutter stores sessions in unencrypted SharedPreferences.", style_bullet))
    story.append(Spacer(1, 4))

    # SECTION 5: SYNERGY WITH GROUP 12
    story.append(Paragraph("5. Alignment & Synergy with Group 12 (Hackers-Healers-1)", style_h1))
    synergy_intro = (
        "There is a <b>natural, symbiotic division of labor</b> between the Summer Mobile App and Group 12's Fall 2026 Proposal "
        "(<i>'e-Hospital AI-Twin: An Agentic Multi-Model Clinical Reasoning Platform'</i>):"
    )
    story.append(Paragraph(synergy_intro, style_body))

    syn_data = [
        [Paragraph("Dimension", style_table_header), Paragraph("Summer Mobile App (Patient-Facing)", style_table_header), Paragraph("Group 12 Hackers-Healers-1 (Clinician-Facing)", style_table_header)],
        [
            Paragraph("<b>Target User</b>", style_table_text),
            Paragraph("Patient / Individual at Home", style_table_text),
            Paragraph("Physician, Nurse Practitioner, Clinic Staff", style_table_text)
        ],
        [
            Paragraph("<b>Primary UI</b>", style_table_text),
            Paragraph("Flutter Mobile App (iOS / Android)", style_table_text),
            Paragraph("React 18 / Vite Responsive Web Dashboard", style_table_text)
        ],
        [
            Paragraph("<b>Core Capabilities</b>", style_table_text),
            Paragraph("• Apple Watch vitals sync<br/>• Medication tracking & symptom logging<br/>• Patient-friendly lab report interpretation<br/>• Urgent care check-in", style_table_text),
            Paragraph("• <b>Ambient Voice Scribe</b> (SOAP note generation)<br/>• <b>3D Interactive Patient Digital Twin</b> (WebGL)<br/>• Canadian Guideline Risk Scorer (Hypertension/Diabetes)<br/>• Automated OHIP Billing & Specialist Referral Fillers", style_table_text)
        ],
        [
            Paragraph("<b>Data Integration</b>", style_table_text),
            Paragraph("Writes home vitals & logs to eHospital MySQL", style_table_text),
            Paragraph("Reads patient vitals into Digital Twin; logs consult notes", style_table_text)
        ]
    ]
    syn_table = Table(syn_data, colWidths=[85, 215, 232])
    syn_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('TOPPADDING', (0,0), (-1,-1), 3.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, BG_LIGHT])
    ]))
    story.append(syn_table)

    story.append(PageBreak())

    # ==================== PAGE 3 ====================
    # SECTION 6: HIGH-IMPACT QUESTIONS FOR THE PROFESSOR (Part 1)
    story.append(Paragraph("6. High-Yield Questions for Tonight's Meeting (8:00 PM)", style_h1))
    
    questions_part1 = [
        ("A. Project Scope & Architecture Boundaries", [
            "<b>Q1:</b> <i>'Do you want Group 12 to directly adopt and maintain this Flutter codebase as our patient mobile client, or should we treat it as an architectural benchmark while delivering our primary web-based Ambient Scribe and 3D Digital Twin?'</i>",
            "<b>Q2:</b> <i>'The summer project introduced an intermediary FastAPI backend. Should we merge our Ambient Voice Scribe and Multi-Agent services into this existing FastAPI service, or maintain microservice boundaries?'</i>"
        ]),
        ("B. Mobile Platform Constraints (iOS HealthKit vs. Android Gap)", [
            "<b>Q3:</b> <i>'The mobile app’s native wearable ingestion is implemented strictly in Swift for iOS HealthKit (<code>AppDelegate.swift</code>), with zero Android Health Connect code. For students or evaluators using Android devices or emulators, are we expected to build the Android Health Connect bridge, or should we rely on the in-app synthetic event injectors (<code>injectTestBloodPressure</code>) for testing and grading?'</i>",
            "<b>Q4:</b> <i>'Real-time background delivery for Apple HealthKit requires paid Apple Developer team provisioning and capabilities in Xcode. Does the faculty provide a shared Apple Developer team profile for device testing, or is the app evaluated via tethered foreground execution?'</i>"
        ]),
        ("C. Database Concurrency & Demo Collisions", [
            "<b>Q5:</b> <i>'The summer seed script specifically configured Patient IDs 391 and 393 on the live AWS MySQL instance. Are other teams actively using these patient IDs, and should our team partition dedicated patient IDs (e.g., 1200+ for Group 12) to avoid race conditions or overwriting other groups’ data during evaluations?'</i>",
            "<b>Q6:</b> <i>'We observed significant latency in patient context fetching due to unindexed sequential queries pulling entire tables. May we refactor the data access layer to use direct parameterized <code>POST /sql/select</code> queries with WHERE clauses to reduce latency from ~6s to &lt;400ms?'</i>"
        ])
    ]

    for cat_title, q_list in questions_part1:
        story.append(Paragraph(f"<b>{cat_title}:</b>", style_h2))
        for q in q_list:
            story.append(Paragraph(f"• {q}", style_bullet))
        story.append(Spacer(1, 2))

    # SECTION 6: HIGH-IMPACT QUESTIONS (Part 2)
    questions_part2 = [
        ("D. Clinical Safety, Privacy & Ethical Compliance (PHIPA / PIPEDA)", [
            "<b>Q7:</b> <i>'In the mobile app's AI assistant, what clinical guardrails are expected for safety? For instance, do you expect deterministic rule-based pre-validation before LLM generation (e.g. flagging critical potassium or troponin values), or is prompt-based system steering with a disclaimer considered sufficient for the rubric?'</i>",
            "<b>Q8:</b> <i>'The mobile backend supports both local Ollama and Google Gemini cloud. For our final grading and live demonstration, is cloud LLM usage allowed with synthetic data, or does the course strictly require 100% on-premise local inference to fulfill Ontario PHIPA / PIPEDA data sovereignty standards?'</i>"
        ]),
        ("E. Telemedicine Integration & Deliverable Weighting", [
            "<b>Q9:</b> <i>'We noticed the summer app includes an Urgent Care check-in screen, but lacks a clinician-facing triage portal. Since our Group 12 platform already features a clinic dashboard with automated triage, would completing this closed-loop workflow—allowing a patient to check in on mobile and appear instantly in our clinic triage queue—be a valuable deliverable for our project?'</i>",
            "<b>Q10:</b> <i>'For our Milestone 3 Midterm Prototype (Nov 4 - 20%), what specific user journey will you and the TAs test during the live presentation? Will you test the mobile app end-to-end, or focus primarily on the core innovations proposed by Group 12 (Ambient Voice Scribe & 3D Digital Twin)?'</i>"
        ])
    ]

    for cat_title, q_list in questions_part2:
        story.append(Paragraph(f"<b>{cat_title}:</b>", style_h2))
        for q in q_list:
            story.append(Paragraph(f"• {q}", style_bullet))
        story.append(Spacer(1, 2))

    story.append(PageBreak())

    # ==================== PAGE 4 ====================
    # SECTION 7: RECOMMENDED STRATEGY FOR TONIGHT
    story.append(Paragraph("7. Strategic Gameplan for Tonight's Meeting", style_h1))
    strat_text = (
        "<b>1. Pitch the 'Two-Tier Ecosystem':</b> Propose positioning the Summer Flutter app as the <b>Patient Telemedicine Client</b> "
        "(capturing vitals, symptoms, and report OCR) and Group 12's <i>Hackers-Healers-1</i> platform as the <b>Physician Clinical Command Center</b> "
        "(ambient voice scribing, 3D anatomical twin, and OHIP billing). This positions your team as systems integrators rather than merely rebuilding existing screens.<br/>"
        "<b>2. Offer a Quick Performance Fix:</b> Mention to the professor that you analyzed their context-fetching pipeline and identified the N+1 query loop. "
        "Offer to contribute an optimized parameterized query layer using <code>POST /sql/select</code> that reduces context latency from ~6s down to &lt;400ms.<br/>"
        "<b>3. Clarify the Missing Workflow File:</b> Inquire gently about <code>health_alert_analysis.py</code>. This demonstrates that you conducted a line-by-line static code analysis and understand the dependency tree.<br/>"
        "<b>4. Lock in Milestone 3 (Nov 4) Deliverables:</b> Ensure the professor clarifies whether live Apple Watch syncing is strictly required for the midterm or if simulated vitals are acceptable."
    )
    story.append(Paragraph(strat_text, style_body))
    story.append(Spacer(1, 6))

    # SECTION 8: QUICK RUN CHEATSHEET
    story.append(Paragraph("8. Pre-Meeting Codebase Quick Reference & Run Commands", style_h1))
    commands_data = [
        [Paragraph("Target Component", style_table_header), Paragraph("Terminal Execution Command (PowerShell / Bash)", style_table_header)],
        [
            Paragraph("<b>Backend Health Check</b>", style_table_text),
            Paragraph("<code>curl http://127.0.0.1:8000/report-interpreter/health</code>", style_table_text)
        ],
        [
            Paragraph("<b>Start AI Backend</b>", style_table_text),
            Paragraph("<code>conda run -n langgraph uvicorn src.backend.main:app --reload --host 0.0.0.0 --port 8000</code>", style_table_text)
        ],
        [
            Paragraph("<b>Flutter Run (Backend Mode)</b>", style_table_text),
            Paragraph("<code>flutter run --dart-define=AI_PROVIDER=backend --dart-define=BACKEND_BASE_URL=http://127.0.0.1:8000</code>", style_table_text)
        ],
        [
            Paragraph("<b>Seed Demo Patient Data</b>", style_table_text),
            Paragraph("<code>python src/datasets/seed_llm_health_scenarios.py --refresh-recent</code> (Seeds Patients 391 & 393)", style_table_text)
        ],
        [
            Paragraph("<b>Inspect Patient Context</b>", style_table_text),
            Paragraph("<code>GET http://127.0.0.1:8000/assistant/patients/391/context</code>", style_table_text)
        ],
        [
            Paragraph("<b>Verify OCR Stack</b>", style_table_text),
            Paragraph("<code>python -c \"import pytesseract, pdf2image; print('OCR Stack Ready')\"</code>", style_table_text)
        ]
    ]
    cmd_table = Table(commands_data, colWidths=[140, 392])
    cmd_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), SECONDARY),
        ('GRID', (0,0), (-1,-1), 0.5, colors.HexColor("#cbd5e1")),
        ('TOPPADDING', (0,0), (-1,-1), 3.5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 3.5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, BG_LIGHT])
    ]))
    story.append(cmd_table)

    # Build the document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"PDF successfully built: {filename}")

if __name__ == "__main__":
    out_path = os.path.join(os.getcwd(), "eHospital_Mobile_App_Review_Notes.pdf")
    build_pdf(out_path)
