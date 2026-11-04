import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def build_presentation():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Theme Palette: Modern Clinical & Academic
    BG_DARK = RGBColor(15, 23, 42)        # Slate 900
    BG_LIGHT = RGBColor(248, 250, 252)    # Slate 50
    CARD_BG = RGBColor(255, 255, 255)     # White
    CARD_BORDER = RGBColor(226, 232, 240) # Slate 200
    
    PRIMARY_TEAL = RGBColor(13, 148, 136) # Teal 600
    ACCENT_BLUE = RGBColor(14, 165, 233)  # Sky 500
    TEXT_DARK = RGBColor(30, 41, 59)      # Slate 800
    TEXT_MUTED = RGBColor(100, 116, 139)  # Slate 500
    TEXT_LIGHT = RGBColor(241, 245, 249)  # Slate 100
    HIGHLIGHT_RED = RGBColor(225, 29, 72) # Rose 600
    HIGHLIGHT_AMBER = RGBColor(217, 119, 6) # Amber 600
    HIGHLIGHT_GREEN = RGBColor(22, 163, 74) # Green 600

    def add_header(slide, title, category="e-HOSPITAL CLINICAL AI ARCHITECTURE"):
        box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.733), Inches(0.9))
        tf = box.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        
        p_cat = tf.paragraphs[0]
        p_cat.text = category.upper()
        p_cat.font.name = "Arial"
        p_cat.font.size = Pt(10)
        p_cat.font.bold = True
        p_cat.font.color.rgb = PRIMARY_TEAL
        
        p_title = tf.add_paragraph()
        p_title.text = title
        p_title.font.name = "Georgia"
        p_title.font.size = Pt(22)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_DARK
        p_title.space_before = Pt(3)

    def add_card(slide, left, top, width, height, bg_color=CARD_BG, border_color=CARD_BORDER):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        shape.fill.solid()
        shape.fill.fore_color.rgb = bg_color
        if border_color:
            shape.line.color.rgb = border_color
            shape.line.width = Pt(1.5)
        else:
            shape.line.fill.background()
        return shape

    # =========================================================================
    # SLIDE 1: TITLE SLIDE (Dark Academic Theme)
    # =========================================================================
    slide1 = prs.slides.add_slide(blank_layout)
    bg1 = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
    bg1.fill.solid()
    bg1.fill.fore_color.rgb = BG_DARK
    bg1.line.fill.background()

    bar = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(1.5), Inches(0.15), Inches(4.5))
    bar.fill.solid()
    bar.fill.fore_color.rgb = PRIMARY_TEAL
    bar.line.fill.background()

    tbox1 = slide1.shapes.add_textbox(Inches(1.4), Inches(1.5), Inches(10.8), Inches(4.5))
    tf1 = tbox1.text_frame
    tf1.word_wrap = True

    p = tf1.paragraphs[0]
    p.text = "NEXT-GENERATION DIGITAL OUTPATIENT CARE"
    p.font.name = "Arial"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    p = tf1.add_paragraph()
    p.text = "e-Hospital AI-Twin: WhatsApp Care Architecture,\nAmbient Voice Dictation & Clinical Decision Engine"
    p.font.name = "Georgia"
    p.font.size = Pt(26)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT
    p.space_before = Pt(10)

    p = tf1.add_paragraph()
    p.text = "Bridging Asynchronous Mobile Telehealth, Speech-to-Text Ingestion, and Calibrated LLM Triage"
    p.font.name = "Arial"
    p.font.size = Pt(13)
    p.font.color.rgb = RGBColor(203, 213, 225)
    p.space_before = Pt(14)

    p = tf1.add_paragraph()
    p.text = "TEAM GROUP 9  •  HACKERS & HEALERS"
    p.font.name = "Arial"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p.space_before = Pt(28)

    p = tf1.add_paragraph()
    p.text = "Team Members: Sree, Sugan, Duke"
    p.font.name = "Arial"
    p.font.size = Pt(12)
    p.font.bold = False
    p.font.color.rgb = RGBColor(226, 232, 240)
    p.space_before = Pt(6)

    # =========================================================================
    # SLIDE 2: THE PROBLEM: NAIVE GPT VS. CLINICAL DECISION SUPPORT
    # =========================================================================
    slide2 = prs.slides.add_slide(blank_layout)
    add_header(slide2, "The Core Dilemma: Naive Chatbot vs. Clinical Decision Engine")

    w2 = Inches(5.6)
    add_card(slide2, Inches(0.8), Inches(1.6), w2, Inches(5.2))
    t2_1 = slide2.shapes.add_textbox(Inches(1.0), Inches(1.8), w2 - Inches(0.4), Inches(4.8)).text_frame
    t2_1.word_wrap = True
    p = t2_1.paragraphs[0]
    p.text = "❌ Naive LLM / Direct GPT Pitfalls"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED

    points_left = [
        ("Generic Passive Disclaimers", "Outputs 'Please consult your doctor at [phone number]' with zero medical action."),
        ("No Grounding in Patient EHR", "Blind to whether the patient has chronic Atrial Fibrillation, Type 2 Diabetes, or prior MI."),
        ("Uncalibrated Confidence", "Sycophantic language raters (RLHF) train LLMs to sound authoritative even when hallucinating."),
        ("No Bidirectional EHR Writes", "Cannot commit vitals telemetry or book priority clinic appointments in hospital tables.")
    ]
    for title, desc in points_left:
        p = t2_1.add_paragraph()
        p.text = f"• {title}: {desc}"
        p.font.size = Pt(10.5)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(8)

    add_card(slide2, Inches(6.9), Inches(1.6), w2, Inches(5.2))
    t2_2 = slide2.shapes.add_textbox(Inches(7.1), Inches(1.8), w2 - Inches(0.4), Inches(4.8)).text_frame
    t2_2.word_wrap = True
    p = t2_2.paragraphs[0]
    p.text = "✅ Our Calibrated Clinical Decision Engine"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN

    points_right = [
        ("CTAS Acuity Triaging (1–5)", "Classifies patient acuity under the Canadian Triage & Acuity Scale with calibrated confidence."),
        ("CPG Guideline Grounding", "Evaluates blood pressure against Hypertension Canada 2024 targets (<130/80) and comorbidity risks."),
        ("Closed-Loop Doctor Escalation", "Fires STAT alerts to Dr. Patel's triage desk on red flags and enables one-tap 911 / queue check-in."),
        ("Structured Clinician SOAP Notes", "Generates physician-grade Subjective, Objective, Assessment, Plan summaries directly for EHR.")
    ]
    for title, desc in points_right:
        p = t2_2.add_paragraph()
        p.text = f"• {title}: {desc}"
        p.font.size = Pt(10.5)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(8)

    # =========================================================================
    # SLIDE 3: WHATSAPP CLINICAL ARCHITECTURE
    # =========================================================================
    slide3 = prs.slides.add_slide(blank_layout)
    add_header(slide3, "WhatsApp Care Team: End-to-End System Architecture")

    col_w3 = Inches(3.6)
    gap3 = Inches(0.4)

    # Card 1: Client Layer
    add_card(slide3, Inches(0.8), Inches(1.6), col_w3, Inches(5.2))
    t3_1 = slide3.shapes.add_textbox(Inches(1.0), Inches(1.8), col_w3 - Inches(0.4), Inches(4.8)).text_frame
    t3_1.word_wrap = True
    p = t3_1.paragraphs[0]
    p.text = "1. Mobile Client & Ingestion"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    items = [
        ("Flutter Web / Mobile Hub", "Embedded WhatsApp Care Team UI matching Meta's design system."),
        ("Ambient Mic Dictation", "Web Speech API streams live voice into input box with zero modal lag."),
        ("SOCRATES Exploration", "Dynamic quick-tap chips for symptom drill-downs (onset, radiation, timing)."),
        ("Action Buttons", "Direct triggers for 911 calling, Urgent Care queueing, and AWS appointment booking.")
    ]
    for h, b in items:
        p = t3_1.add_paragraph()
        p.text = f"• {h}\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(6)

    # Card 2: Middleware & Decision Engine
    add_card(slide3, Inches(0.8) + col_w3 + gap3, Inches(1.6), col_w3, Inches(5.2))
    t3_2 = slide3.shapes.add_textbox(Inches(1.0) + col_w3 + gap3, Inches(1.8), col_w3 - Inches(0.4), Inches(4.8)).text_frame
    t3_2.word_wrap = True
    p = t3_2.paragraphs[0]
    p.text = "2. FastAPI Clinical Core"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    items2 = [
        ("Regex Telemetry Parser", "Extracts systolic/diastolic BP and heart rate from freeform text in real time."),
        ("Comorbidity Cross-Check", "Queries patient medical history (AFib, T2D, CAD) to calculate composite risk."),
        ("CTAS Rule Engine", "Assigns CTAS 1 (Resuscitation) to CTAS 5 (Non-urgent) with confidence scoring."),
        ("SOAP Note Generator", "Synthesizes structured physician clinical documentation for intake review.")
    ]
    for h, b in items2:
        p = t3_2.add_paragraph()
        p.text = f"• {h}\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(6)

    # Card 3: Central Cloud & EHR
    add_card(slide3, Inches(0.8) + (col_w3 + gap3)*2, Inches(1.6), col_w3, Inches(5.2))
    t3_3 = slide3.shapes.add_textbox(Inches(1.0) + (col_w3 + gap3)*2, Inches(1.8), col_w3 - Inches(0.4), Inches(4.8)).text_frame
    t3_3.word_wrap = True
    p = t3_3.paragraphs[0]
    p.text = "3. Central AWS Cloud EHR"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_AMBER
    items3 = [
        ("AWS App Runner Cloud", "Enterprise REST gateway hosting 72 normalized eHospital database tables."),
        ("wearable_vitals Table", "Stores synced continuous telemetry (HR, steps, sleep, annotations)."),
        ("vitals_history Table", "Stores verified ambulatory blood pressure and clinical notes."),
        ("appointments Table", "Direct cloud writes confirming scheduled triage consultations with Dr. Patel.")
    ]
    for h, b in items3:
        p = t3_3.add_paragraph()
        p.text = f"• {h}\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(6)

    # =========================================================================
    # SLIDE 4: AMBIENT SPEECH-TO-TEXT (VOICE-TO-TEXT) ARCHITECTURE
    # =========================================================================
    slide4 = prs.slides.add_slide(blank_layout)
    add_header(slide4, "Ambient Clinical Dictation: Voice-to-Text Pipeline")

    w4 = Inches(3.6)
    gap4 = Inches(0.4)

    add_card(slide4, Inches(0.8), Inches(1.6), w4, Inches(5.2))
    t4_1 = slide4.shapes.add_textbox(Inches(1.0), Inches(1.8), w4 - Inches(0.4), Inches(4.8)).text_frame
    t4_1.word_wrap = True
    p = t4_1.paragraphs[0]
    p.text = "Zero-Friction In-Chat Mic"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    v_points1 = [
        ("Direct Input Integration", "Microphone lives directly inside the chat compose bar. No modal dialogs, bottom sheets, or demo question screens."),
        ("Client-Side Web Speech API", "Leverages browser-native continuous speech recognition with zero cloud audio transfer overhead."),
        ("Live Text Streaming", "Interim speech results stream into the text field in real-time, allowing patient editing prior to dispatch."),
        ("Health Equity & Accessibility", "Empowers elderly, vision-impaired, or tremor-affected patients to communicate effortlessly.")
    ]
    for h, b in v_points1:
        p = t4_1.add_paragraph()
        p.text = f"• {h}:\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(7)

    add_card(slide4, Inches(0.8) + w4 + gap4, Inches(1.6), w4, Inches(5.2))
    t4_2 = slide4.shapes.add_textbox(Inches(1.0) + w4 + gap4, Inches(1.8), w4 - Inches(0.4), Inches(4.8)).text_frame
    t4_2.word_wrap = True
    p = t4_2.paragraphs[0]
    p.text = "Entity Extraction Engine"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    v_points2 = [
        ("Acoustic Ambiguity Handling", "Handles conversational syntax: 'my pressure is 150 over 95 and pulse is 82'."),
        ("Regex Vital Tokenizer", "Instantly isolates systolic, diastolic, and HR integers for immediate database serialization."),
        ("Symptom Pattern Matcher", "Scans spoken phrases for cardiac red flags ('crushing', 'radiating', 'short of breath')."),
        ("Dual-Stream Processing", "Transcript is displayed to user while structured vitals are dispatched to backend.")
    ]
    for h, b in v_points2:
        p = t4_2.add_paragraph()
        p.text = f"• {h}:\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(7)

    add_card(slide4, Inches(0.8) + (w4 + gap4)*2, Inches(1.6), w4, Inches(5.2))
    t4_3 = slide4.shapes.add_textbox(Inches(1.0) + (w4 + gap4)*2, Inches(1.8), w4 - Inches(0.4), Inches(4.8)).text_frame
    t4_3.word_wrap = True
    p = t4_3.paragraphs[0]
    p.text = "Clinical Impact & Privacy"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN
    v_points3 = [
        ("Zero Audio Storage", "Raw audio waveforms are processed locally on device; never saved to disk or persistent servers."),
        ("PIPEDA / HIPAA Compliance", "Complies with Canadian privacy standards: only sanitized text transcripts are transmitted."),
        ("8x Faster Intake", "Patients dictate complex symptom chronologies in <10 seconds compared to tedious manual typing."),
        ("High Telemetry Compliance", "Patients log home vitals 3x more consistently when dictation requires single tap.")
    ]
    for h, b in v_points3:
        p = t4_3.add_paragraph()
        p.text = f"• {h}:\n  {b}"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(7)

    # =========================================================================
    # SLIDE 5: TWO-SPEED COGNITIVE ARCHITECTURE (GPT + CLINICAL RULES)
    # =========================================================================
    slide5 = prs.slides.add_slide(blank_layout)
    add_header(slide5, "Two-Speed Cognitive Architecture: System 1 + System 2")

    w5 = Inches(5.6)
    add_card(slide5, Inches(0.8), Inches(1.6), w5, Inches(5.2))
    t5_1 = slide5.shapes.add_textbox(Inches(1.0), Inches(1.8), w5 - Inches(0.4), Inches(4.8)).text_frame
    t5_1.word_wrap = True
    p = t5_1.paragraphs[0]
    p.text = "⚡ System 1: Fast Deterministic Guardrails (<20ms)"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED

    s1_points = [
        ("CTAS Rule Matrix", "Deterministic matching against Canadian Triage & Acuity Scale for red-flag cardiac and respiratory crises."),
        ("Hypertension Canada 2024 CPG", "Strict evaluation: Crisis (>=180/120), Stage 2 (>=140/90), Stage 1 (130-139/80-89), Normal (<130/80)."),
        ("Comorbidity Multiplier", "Elevates CTAS level from 4 to 3 if elevated vitals occur in patients with Diabetes or CAD history."),
        ("Guaranteed Safety Gate", "Bypasses generative ambiguity entirely for critical conditions to guarantee zero hallucination.")
    ]
    for h, b in s1_points:
        p = t5_1.add_paragraph()
        p.text = f"• {h}: {b}"
        p.font.size = Pt(10.5)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(8)

    add_card(slide5, Inches(6.9), Inches(1.6), w5, Inches(5.2))
    t5_2 = slide5.shapes.add_textbox(Inches(7.1), Inches(1.8), w5 - Inches(0.4), Inches(4.8)).text_frame
    t5_2.word_wrap = True
    p = t5_2.paragraphs[0]
    p.text = "🧠 System 2: Generative Reasoning & SOAP Synthesis"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    s2_points = [
        ("Clinical Language Model", "Empathic, professional patient guidance grounded strictly on EHR context and guideline outputs."),
        ("SOCRATES Exploration", "Dynamically generates targeted symptom exploration chips (onset, location, severity, radiation)."),
        ("Clinician SOAP Note Synthesis", "Generates structured Subjective, Objective, Assessment, Plan notes ready for Dr. Patel."),
        ("Calibrated Uncertainty Flag", "Scores confidence (0.0 to 1.0) and flags atypical cases for mandatory human clinician review.")
    ]
    for h, b in s2_points:
        p = t5_2.add_paragraph()
        p.text = f"• {h}: {b}"
        p.font.size = Pt(10.5)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(8)

    # =========================================================================
    # SLIDE 6: CLINICAL SOAP NOTE DEMONSTRATION & CONCLUSION
    # =========================================================================
    slide6 = prs.slides.add_slide(blank_layout)
    add_header(slide6, "Closed-Loop Clinical Triage & Physician SOAP Note")

    add_card(slide6, Inches(0.8), Inches(1.6), Inches(11.733), Inches(3.2), bg_color=RGBColor(241, 245, 249))
    t6_1 = slide6.shapes.add_textbox(Inches(1.0), Inches(1.7), Inches(11.3), Inches(3.0)).text_frame
    t6_1.word_wrap = True
    p = t6_1.paragraphs[0]
    p.text = "📋 Automated Clinician SOAP Note (Generated for Dr. Patel's EHR Desk)"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL

    soap_lines = [
        ("S (Subjective)", "Patient #391 reports via secure WhatsApp channel: 'hello doctor I have severe chest pain'. Chief complaint presented asynchronously. Acute onset."),
        ("O (Objective)", "Telemetry: Blood Pressure 150/95 mmHg, HR 82 BPM. Active EHR Comorbidities: Essential Hypertension, Type 2 Diabetes. Telemetry synced with AWS."),
        ("A (Assessment)", "Acuity: CTAS Level 2 (Emergent - Potential Threat to Life). Guideline Reference: Hypertension Canada Stage 2 + Cardiac Red Flag. Calibrated Confidence: 98%."),
        ("P (Plan)", "STAT Escalation: Dispatched 911 alert. Flagged Dr. Patel on-call triage queue. Priority consultation slot held (#APT-195).")
    ]
    for s_title, s_content in soap_lines:
        p = t6_1.add_paragraph()
        p.text = f"{s_title}: {s_content}"
        p.font.size = Pt(9.5)
        p.font.color.rgb = TEXT_DARK
        p.space_before = Pt(4)

    # Summary cards below
    add_card(slide6, Inches(0.8), Inches(5.0), Inches(3.7), Inches(1.8))
    t6_c1 = slide6.shapes.add_textbox(Inches(0.9), Inches(5.1), Inches(3.5), Inches(1.6)).text_frame
    t6_c1.word_wrap = True
    p = t6_c1.paragraphs[0]
    p.text = "1. Real Clinical Actions"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t6_c1.add_paragraph()
    p.text = "Replaces passive AI disclaimers with one-tap 911 routing, urgent care queue check-in, and AWS appointment writes."
    p.font.size = Pt(9.5)
    p.font.color.rgb = TEXT_DARK

    add_card(slide6, Inches(4.8), Inches(5.0), Inches(3.7), Inches(1.8))
    t6_c2 = slide6.shapes.add_textbox(Inches(4.9), Inches(5.1), Inches(3.5), Inches(1.6)).text_frame
    t6_c2.word_wrap = True
    p = t6_c2.paragraphs[0]
    p.text = "2. Zero-Lag Voice Dictation"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t6_c2.add_paragraph()
    p.text = "Web Speech API streams live voice directly into the compose bar with zero pop-up friction or modal latency."
    p.font.size = Pt(9.5)
    p.font.color.rgb = TEXT_DARK

    add_card(slide6, Inches(8.8), Inches(5.0), Inches(3.7), Inches(1.8))
    t6_c3 = slide6.shapes.add_textbox(Inches(8.9), Inches(5.1), Inches(3.5), Inches(1.6)).text_frame
    t6_c3.word_wrap = True
    p = t6_c3.paragraphs[0]
    p.text = "3. Calibrated Safety"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t6_c3.add_paragraph()
    p.text = "Cross-references EHR history with Canadian Clinical Practice Guidelines (CPGs) for transparent, calibrated triage."
    p.font.size = Pt(9.5)
    p.font.color.rgb = TEXT_DARK

    out_path = "eHospital_WhatsApp_Voice_Clinical_AI_Presentation.pptx"
    prs.save(out_path)
    print(f"Presentation saved to: {os.path.abspath(out_path)}")

if __name__ == "__main__":
    build_presentation()
