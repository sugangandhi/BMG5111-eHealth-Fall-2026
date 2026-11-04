import os
import sys
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def build_human_grade_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6]

    # Executive Medical Palette
    BG_DARK = RGBColor(15, 23, 42)          # Deep Slate 900
    BG_LIGHT = RGBColor(248, 250, 252)      # Slate 50
    CARD_BG = RGBColor(255, 255, 255)       # Pure White
    CARD_BORDER = RGBColor(226, 232, 240)   # Slate 200
    CARD_SUBTLE = RGBColor(241, 245, 249)   # Slate 100
    
    PRIMARY_TEAL = RGBColor(13, 148, 136)   # Teal 600
    PRIMARY_TEAL_DARK = RGBColor(15, 118, 110) # Teal 700
    ACCENT_BLUE = RGBColor(14, 165, 233)    # Sky 500
    ACCENT_BLUE_DARK = RGBColor(2, 132, 199)# Sky 600
    TEXT_DARK = RGBColor(30, 41, 59)        # Slate 800
    TEXT_MUTED = RGBColor(100, 116, 139)    # Slate 500
    TEXT_LIGHT = RGBColor(248, 250, 252)    # Slate 50
    
    ALERT_RED = RGBColor(225, 29, 72)       # Rose 600
    ALERT_RED_BG = RGBColor(255, 241, 242)  # Rose 50
    ALERT_AMBER = RGBColor(217, 119, 6)     # Amber 600
    ALERT_AMBER_BG = RGBColor(254, 243, 199)# Amber 50
    SUCCESS_GREEN = RGBColor(22, 163, 74)   # Green 600
    SUCCESS_GREEN_BG = RGBColor(240, 253, 244) # Green 50

    def apply_background(slide, color):
        bg = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
        bg.fill.solid()
        bg.fill.fore_color.rgb = color
        bg.line.color.rgb = color
        bg.line.width = Pt(1)
        return bg

    def add_header(slide, title, category="e-HOSPITAL CLINICAL AI ARCHITECTURE"):
        box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.733), Inches(0.95))
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
        p_title.font.size = Pt(23)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_DARK
        p_title.space_before = Pt(3)

    def add_card(slide, left, top, width, height, bg_color=CARD_BG, border_color=CARD_BORDER, border_width=1.5):
        shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        shape.fill.solid()
        shape.fill.fore_color.rgb = bg_color
        if border_color:
            shape.line.color.rgb = border_color
            shape.line.width = Pt(border_width)
        else:
            shape.line.color.rgb = bg_color
            shape.line.width = Pt(1)
        return shape

    def add_pill_badge(slide, left, top, width, height, text, bg_color, text_color):
        badge = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
        badge.fill.solid()
        badge.fill.fore_color.rgb = bg_color
        badge.line.color.rgb = bg_color
        badge.line.width = Pt(1)
        tf = badge.text_frame
        tf.word_wrap = True
        tf.margin_left = tf.margin_top = tf.margin_right = tf.margin_bottom = 0
        p = tf.paragraphs[0]
        p.text = text
        p.alignment = PP_ALIGN.CENTER
        p.font.name = "Arial"
        p.font.size = Pt(9.5)
        p.font.bold = True
        p.font.color.rgb = text_color
        return badge

    def add_arrow_right(slide, left, top, width=Inches(0.3), height=Inches(0.35), color=PRIMARY_TEAL):
        arrow = slide.shapes.add_shape(MSO_SHAPE.RIGHT_ARROW, left, top, width, height)
        arrow.fill.solid()
        arrow.fill.fore_color.rgb = color
        arrow.line.color.rgb = color
        arrow.line.width = Pt(1)
        return arrow

    def add_arrow_down(slide, left, top, width=Inches(0.35), height=Inches(0.3), color=PRIMARY_TEAL):
        arrow = slide.shapes.add_shape(MSO_SHAPE.DOWN_ARROW, left, top, width, height)
        arrow.fill.solid()
        arrow.fill.fore_color.rgb = color
        arrow.line.color.rgb = color
        arrow.line.width = Pt(1)
        return arrow

    # =========================================================================
    # SLIDE 1: COVER SLIDE
    # =========================================================================
    slide1 = prs.slides.add_slide(blank_layout)
    apply_background(slide1, BG_DARK)

    bar = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(1.5), Inches(0.12), Inches(4.5))
    bar.fill.solid()
    bar.fill.fore_color.rgb = PRIMARY_TEAL
    bar.line.color.rgb = PRIMARY_TEAL
    bar.line.width = Pt(1)

    tbox1 = slide1.shapes.add_textbox(Inches(1.35), Inches(1.5), Inches(10.8), Inches(4.5))
    tf1 = tbox1.text_frame
    tf1.word_wrap = True

    p = tf1.paragraphs[0]
    p.text = "eHEALTH INNOVATION SEMINAR | DIGITAL OUTPATIENT ARCHITECTURE"
    p.font.name = "Arial"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    p = tf1.add_paragraph()
    p.text = "e-Hospital AI-Twin:\nWhatsApp Clinical Architecture, Ambient Voice Scribe\n& Calibrated Clinical Decision Engine"
    p.font.name = "Georgia"
    p.font.size = Pt(26)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT
    p.space_before = Pt(10)

    p = tf1.add_paragraph()
    p.text = "Bridging Asynchronous Mobile Telehealth, Native Speech Ingestion, and Guideline-Directed Triage"
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
    # SLIDE 2: THE CLINICAL PROBLEM (NAIVE LLM VS CALIBRATED ENGINE)
    # =========================================================================
    slide2 = prs.slides.add_slide(blank_layout)
    apply_background(slide2, BG_LIGHT)
    add_header(slide2, "The Clinical Dilemma: Naive Chatbot vs. Calibrated Triage Engine")

    col_w2 = Inches(5.65)
    
    add_card(slide2, Inches(0.8), Inches(1.55), col_w2, Inches(5.35), bg_color=CARD_BG, border_color=ALERT_RED, border_width=2.0)
    add_pill_badge(slide2, Inches(1.1), Inches(1.8), Inches(2.8), Inches(0.35), "❌ NAIVE LLM / DIRECT CHATBOT", ALERT_RED_BG, ALERT_RED)

    t2_left = slide2.shapes.add_textbox(Inches(1.1), Inches(2.3), col_w2 - Inches(0.6), Inches(4.3)).text_frame
    t2_left.word_wrap = True

    left_pitfalls = [
        ("Passive Generic Disclaimers", "Replies 'Please consult your doctor at [phone number]' with zero clinical action taken."),
        ("Blind to Patient Health History", "Zero awareness of active EHR records (e.g., patient has chronic Atrial Fibrillation or prior myocardial infarction)."),
        ("Uncalibrated Overconfidence", "RLHF conversational training rewards authoritative tone, masking dangerous hallucinations in complex presentations."),
        ("No Bidirectional EHR Integration", "Cannot commit vitals telemetry or book emergency appointments into hospital databases.")
    ]
    for idx, (title, desc) in enumerate(left_pitfalls):
        p = t2_left.paragraphs[0] if idx == 0 else t2_left.add_paragraph()
        p.text = f"{idx+1}. {title}"
        p.font.name = "Arial"
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = ALERT_RED
        if idx > 0:
            p.space_before = Pt(8)
        
        p_desc = t2_left.add_paragraph()
        p_desc.text = desc
        p_desc.font.name = "Arial"
        p_desc.font.size = Pt(10)
        p_desc.font.color.rgb = TEXT_DARK
        p_desc.space_before = Pt(2)

    add_card(slide2, Inches(6.85), Inches(1.55), col_w2, Inches(5.35), bg_color=CARD_BG, border_color=PRIMARY_TEAL, border_width=2.0)
    add_pill_badge(slide2, Inches(7.15), Inches(1.8), Inches(3.2), Inches(0.35), "✅ OUR CALIBRATED CLINICAL ENGINE", SUCCESS_GREEN_BG, PRIMARY_TEAL)

    t2_right = slide2.shapes.add_textbox(Inches(7.15), Inches(2.3), col_w2 - Inches(0.6), Inches(4.3)).text_frame
    t2_right.word_wrap = True

    right_solutions = [
        ("Canadian Triage & Acuity Scale (CTAS)", "Classifies patients under CTAS 1 (Resuscitation) through CTAS 5 (Non-urgent) with calibrated confidence."),
        ("Clinical Practice Guideline (CPG) Grounding", "Evaluates telemetry against Hypertension Canada 2024 thresholds (<130/80) and comorbidity multipliers."),
        ("Direct Physician Escalation", "Dispatches instant STAT alerts to Dr. Patel's triage desk on acute red flags with one-tap 911 dialing."),
        ("Automated Clinician SOAP Notes", "Generates structured Subjective, Objective, Assessment, Plan notes committed directly to hospital records.")
    ]
    for idx, (title, desc) in enumerate(right_solutions):
        p = t2_right.paragraphs[0] if idx == 0 else t2_right.add_paragraph()
        p.text = f"{idx+1}. {title}"
        p.font.name = "Arial"
        p.font.size = Pt(12)
        p.font.bold = True
        p.font.color.rgb = PRIMARY_TEAL
        if idx > 0:
            p.space_before = Pt(8)
        
        p_desc = t2_right.add_paragraph()
        p_desc.text = desc
        p_desc.font.name = "Arial"
        p_desc.font.size = Pt(10)
        p_desc.font.color.rgb = TEXT_DARK
        p_desc.space_before = Pt(2)

    # =========================================================================
    # SLIDE 3: VISUAL ARCHITECTURE FLOWCHART (DIAGRAM SLIDE)
    # =========================================================================
    slide3 = prs.slides.add_slide(blank_layout)
    apply_background(slide3, BG_LIGHT)
    add_header(slide3, "System Architecture: End-to-End Dataflow Diagram", "FULL-STACK VISUAL ARCHITECTURE")

    # Box 1: Mobile Client (Top Left)
    b1 = add_card(slide3, Inches(0.8), Inches(1.55), Inches(5.4), Inches(2.35), bg_color=CARD_BG, border_color=PRIMARY_TEAL, border_width=2.0)
    add_pill_badge(slide3, Inches(1.0), Inches(1.7), Inches(3.2), Inches(0.3), "📱 TIER 1: PATIENT CLIENT (FLUTTER)", CARD_SUBTLE, PRIMARY_TEAL)
    tb1 = slide3.shapes.add_textbox(Inches(1.0), Inches(2.1), Inches(5.0), Inches(1.7)).text_frame
    tb1.word_wrap = True
    p = tb1.paragraphs[0]
    p.text = "• WhatsApp In-App Clinic UI (Meta-verified styling)\n• Direct In-Chatbox Mic (Web Speech API, zero modal lag)\n• Dynamic SOCRATES chips (One-tap symptom drill-down)\n• Interactive action triggers (911 call, urgent care, booking)"
    p.font.name = "Arial"
    p.font.size = Pt(10)
    p.font.color.rgb = TEXT_DARK

    # Arrow 1 -> 2 (Horizontal)
    add_arrow_right(slide3, Inches(6.35), Inches(2.55), Inches(0.45), Inches(0.4), color=PRIMARY_TEAL)

    # Box 2: FastAPI Middleware (Top Right)
    b2 = add_card(slide3, Inches(6.95), Inches(1.55), Inches(5.55), Inches(2.35), bg_color=CARD_BG, border_color=ACCENT_BLUE_DARK, border_width=2.0)
    add_pill_badge(slide3, Inches(7.15), Inches(1.7), Inches(3.5), Inches(0.3), "⚙️ TIER 2: FASTAPI CLINICAL CORE (PORT 8080)", CARD_SUBTLE, ACCENT_BLUE_DARK)
    tb2 = slide3.shapes.add_textbox(Inches(7.15), Inches(2.1), Inches(5.15), Inches(1.7)).text_frame
    tb2.word_wrap = True
    p = tb2.paragraphs[0]
    p.text = "• Regex Vital Tokenizer (Parses BP 150/95 & HR integers)\n• CTAS Acuity Matrix (Deterministic Levels 1 to 5 triage)\n• Hypertension Canada 2024 CPG Grounding (<130/80)\n• Clinician SOAP Note Engine (Subjective, Objective, Plan)"
    p.font.name = "Arial"
    p.font.size = Pt(10)
    p.font.color.rgb = TEXT_DARK

    # Down Arrows from Middleware to Cloud & Clinician Desk
    add_arrow_down(slide3, Inches(3.3), Inches(4.05), Inches(0.4), Inches(0.4), color=ALERT_AMBER)
    add_arrow_down(slide3, Inches(9.5), Inches(4.05), Inches(0.4), Inches(0.4), color=ALERT_RED)

    # Box 3: Central AWS Cloud EHR (Bottom Left)
    b3 = add_card(slide3, Inches(0.8), Inches(4.6), Inches(5.4), Inches(2.35), bg_color=CARD_BG, border_color=ALERT_AMBER, border_width=2.0)
    add_pill_badge(slide3, Inches(1.0), Inches(4.75), Inches(3.6), Inches(0.3), "☁️ TIER 3: CENTRAL AWS CLOUD (APP RUNNER)", CARD_SUBTLE, ALERT_AMBER)
    tb3 = slide3.shapes.add_textbox(Inches(1.0), Inches(5.15), Inches(5.0), Inches(1.7)).text_frame
    tb3.word_wrap = True
    p = tb3.paragraphs[0]
    p.text = "• 72 Normalized eHospital tables (REST API gateway)\n• table/wearable_vitals (Real-time telemetry ingestion)\n• table/medical_history (EHR comorbidity cross-checks)\n• table/appointments (Immediate priority slot booking)"
    p.font.name = "Arial"
    p.font.size = Pt(10)
    p.font.color.rgb = TEXT_DARK

    # Box 4: Clinician Desk & Closed Loop (Bottom Right)
    b4 = add_card(slide3, Inches(6.95), Inches(4.6), Inches(5.55), Inches(2.35), bg_color=CARD_BG, border_color=ALERT_RED, border_width=2.0)
    add_pill_badge(slide3, Inches(7.15), Inches(4.75), Inches(3.8), Inches(0.3), "🩺 TIER 4: DR. PATEL'S DESK & EMERGENCY", CARD_SUBTLE, ALERT_RED)
    tb4 = slide3.shapes.add_textbox(Inches(7.15), Inches(5.15), Inches(5.15), Inches(1.7)).text_frame
    tb4.word_wrap = True
    p = tb4.paragraphs[0]
    p.text = "• STAT Clinical Alerts (Dispatched instantly on red-flags)\n• Collapsible SOAP Notes (Full medical documentation)\n• Priority Triage Queue (Awaiting physician review)\n• Closed-loop actions (Dial 911 / Urgent Care Check-in)"
    p.font.name = "Arial"
    p.font.size = Pt(10)
    p.font.color.rgb = TEXT_DARK

    # =========================================================================
    # SLIDE 4: 4-TIER ARCHITECTURAL PIPELINE (PIPELINE VIEW)
    # =========================================================================
    slide4 = prs.slides.add_slide(blank_layout)
    apply_background(slide4, BG_LIGHT)
    add_header(slide4, "Architectural Pipeline: Component & Protocol Breakdown")

    tier_w = Inches(2.55)
    arrow_w = Inches(0.28)
    gap_tier = Inches(0.18)

    tiers = [
        ("TIER 1: CLIENT", "📱 Flutter App", PRIMARY_TEAL, [
            ("WhatsApp Care Hub", "Meta-styled in-app clinic"),
            ("In-Chatbox Mic", "Browser Web Speech API"),
            ("SOCRATES Chips", "One-tap symptom options"),
            ("Action Triggers", "911 call, queue, booking")
        ]),
        ("TIER 2: INGEST", "⚡ FastAPI Core", ACCENT_BLUE, [
            ("Regex Tokenizer", "Extracts BP & HR integers"),
            ("Telemetry Queue", "Processes ambulatory logs"),
            ("PNA CORS Security", "Private Network Access"),
            ("Session State", "Conversation persistence")
        ]),
        ("TIER 3: REASON", "🧠 Clinical Engine", PRIMARY_TEAL_DARK, [
            ("CTAS Rule Matrix", "Acuity 1–5 classification"),
            ("Canadian CPGs", "Hypertension Canada 2024"),
            ("EHR Cross-Check", "Correlates T2D, AFib, CAD"),
            ("SOAP Synthesizer", "Doctor intake notes")
        ]),
        ("TIER 4: EHR/CLINIC", "☁️ AWS & Doctor", ALERT_AMBER, [
            ("App Runner REST", "72 normalized tables"),
            ("wearable_vitals", "Telemetry sink"),
            ("appointments", "Live booked visits"),
            ("Dr. Patel Desk", "STAT alerts & SOAP review")
        ])
    ]

    for idx, (tier_tag, tier_title, color, bullet_list) in enumerate(tiers):
        left_pos = Inches(0.7) + (tier_w + arrow_w + gap_tier * 2) * idx
        add_card(slide4, left_pos, Inches(1.55), tier_w, Inches(5.35), bg_color=CARD_BG, border_color=color, border_width=1.8)
        add_pill_badge(slide4, left_pos + Inches(0.15), Inches(1.75), tier_w - Inches(0.3), Inches(0.32), tier_tag, CARD_SUBTLE, color)

        t_box = slide4.shapes.add_textbox(left_pos + Inches(0.15), Inches(2.2), tier_w - Inches(0.3), Inches(4.5)).text_frame
        t_box.word_wrap = True

        p_main = t_box.paragraphs[0]
        p_main.text = tier_title
        p_main.font.name = "Georgia"
        p_main.font.size = Pt(13)
        p_main.font.bold = True
        p_main.font.color.rgb = TEXT_DARK

        for b_idx, (head, sub) in enumerate(bullet_list):
            p_head = t_box.add_paragraph()
            p_head.text = f"• {head}"
            p_head.font.name = "Arial"
            p_head.font.size = Pt(10)
            p_head.font.bold = True
            p_head.font.color.rgb = color
            p_head.space_before = Pt(7)

            p_sub = t_box.add_paragraph()
            p_sub.text = sub
            p_sub.font.name = "Arial"
            p_sub.font.size = Pt(9)
            p_sub.font.color.rgb = TEXT_MUTED
            p_sub.space_before = Pt(1)

        # Connector arrow to next tier
        if idx < len(tiers) - 1:
            arr_left = left_pos + tier_w + gap_tier
            add_arrow_right(slide4, arr_left, Inches(4.0), arrow_w, Inches(0.35), color=PRIMARY_TEAL)

    # =========================================================================
    # SLIDE 5: AMBIENT VOICE-TO-TEXT ARCHITECTURE
    # =========================================================================
    slide5 = prs.slides.add_slide(blank_layout)
    apply_background(slide5, BG_LIGHT)
    add_header(slide5, "Ambient Clinical Dictation: Voice-to-Text Architecture")

    w5_card = Inches(3.45)
    gap5 = Inches(0.2)
    arrow5_w = Inches(0.28)

    steps5 = [
        ("STEP 1: CAPTURE", "🎙️ Edge Speech Recognition", PRIMARY_TEAL, [
            ("Zero-Friction In-Chat Mic", "Embedded natively inside compose bar—no popups, sheets, or demo questions."),
            ("Web Speech API Engine", "Browser-native continuous speech recognition with local client-side processing."),
            ("Real-Time Word Streaming", "Words stream live into text box as spoken, allowing patient review before dispatch.")
        ]),
        ("STEP 2: EXTRACTION", "🔍 Dual-Stream Parsing", ACCENT_BLUE, [
            ("Regex Vital Tokenizer", "Instantly isolates systolic/diastolic blood pressure (e.g. '150/95') and HR integers."),
            ("Cardiac Keyword Scanner", "Detects acute symptom descriptors in spoken phrasing ('crushing', 'radiating')."),
            ("Dual-Channel Dispatch", "Displays clean narrative transcript to patient while structured telemetry is sent to API.")
        ]),
        ("STEP 3: CLOUD SYNC", "🛡️ Privacy & EHR Writes", SUCCESS_GREEN, [
            ("Zero Audio Storage", "Audio processed entirely on-device; no voice recordings are stored or sent to cloud."),
            ("PIPEDA / HIPAA Compliance", "Complies with Canadian clinical privacy standards—only verified text entities enter EHR."),
            ("Direct Cloud Telemetry", "Writes verified metrics immediately to AWS table wearable_vitals and vitals_history.")
        ])
    ]

    for idx, (tag, title, color, items) in enumerate(steps5):
        left_pos = Inches(0.8) + (w5_card + arrow5_w + gap5 * 2) * idx
        add_card(slide5, left_pos, Inches(1.55), w5_card, Inches(5.35), bg_color=CARD_BG, border_color=color, border_width=1.8)
        add_pill_badge(slide5, left_pos + Inches(0.2), Inches(1.75), w5_card - Inches(0.4), Inches(0.32), tag, CARD_SUBTLE, color)

        t_box = slide5.shapes.add_textbox(left_pos + Inches(0.2), Inches(2.2), w5_card - Inches(0.4), Inches(4.5)).text_frame
        t_box.word_wrap = True

        p_title = t_box.paragraphs[0]
        p_title.text = title
        p_title.font.name = "Georgia"
        p_title.font.size = Pt(13)
        p_title.font.bold = True
        p_title.font.color.rgb = TEXT_DARK

        for b_idx, (head, sub) in enumerate(items):
            p_head = t_box.add_paragraph()
            p_head.text = f"{b_idx+1}. {head}"
            p_head.font.name = "Arial"
            p_head.font.size = Pt(10.5)
            p_head.font.bold = True
            p_head.font.color.rgb = color
            p_head.space_before = Pt(8)

            p_sub = t_box.add_paragraph()
            p_sub.text = sub
            p_sub.font.name = "Arial"
            p_sub.font.size = Pt(9.5)
            p_sub.font.color.rgb = TEXT_DARK
            p_sub.space_before = Pt(2)

        if idx < len(steps5) - 1:
            arr_left = left_pos + w5_card + gap5
            add_arrow_right(slide5, arr_left, Inches(4.0), arrow5_w, Inches(0.35), color=PRIMARY_TEAL)

    # =========================================================================
    # SLIDE 6: TWO-SPEED COGNITIVE ARCHITECTURE (SYSTEM 1 + SYSTEM 2)
    # =========================================================================
    slide6 = prs.slides.add_slide(blank_layout)
    apply_background(slide6, BG_LIGHT)
    add_header(slide6, "Two-Speed Cognitive Architecture: System 1 + System 2")

    banner = add_card(slide6, Inches(0.8), Inches(1.55), Inches(11.733), Inches(0.95), bg_color=CARD_SUBTLE, border_color=CARD_BORDER)
    tb_banner = slide6.shapes.add_textbox(Inches(1.0), Inches(1.65), Inches(11.3), Inches(0.75)).text_frame
    tb_banner.word_wrap = True
    p = tb_banner.paragraphs[0]
    p.text = "PATIENT MESSAGE INGESTION STREAM: \"Doctor, I have severe chest pain and my blood pressure is 150/95\""
    p.font.name = "Arial"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p_b2 = tb_banner.add_paragraph()
    p_b2.text = "EHR Context Hydration: Patient #391 | Known Comorbidities: Essential Hypertension, Type 2 Diabetes"
    p_b2.font.name = "Arial"
    p_b2.font.size = Pt(10)
    p_b2.font.color.rgb = TEXT_MUTED

    w6_card = Inches(5.65)

    add_card(slide6, Inches(0.8), Inches(2.7), w6_card, Inches(4.2), bg_color=CARD_BG, border_color=ALERT_RED, border_width=2.0)
    add_pill_badge(slide6, Inches(1.1), Inches(2.9), Inches(3.6), Inches(0.32), "⚡ SYSTEM 1: DETERMINISTIC GUARDRAILS (<20ms)", ALERT_RED_BG, ALERT_RED)

    t6_left = slide6.shapes.add_textbox(Inches(1.1), Inches(3.35), w6_card - Inches(0.6), Inches(3.3)).text_frame
    t6_left.word_wrap = True
    s1_items = [
        ("CTAS Acuity Rule Matrix", "Deterministic matching against Canadian Triage & Acuity Scale for cardiac emergencies (CTAS Level 1/2)."),
        ("Hypertension Canada 2024 CPG", "Classifies BP >=140/90 as Stage 2; >=180/120 as Crisis. Evaluates target organ damage risk."),
        ("Comorbidity Multiplier", "Elevates triage acuity automatically when Stage 2 BP coincides with chronic diabetes or CAD."),
        ("Guaranteed Zero Hallucination", "Bypasses generative ambiguity entirely for life-threatening presentations.")
    ]
    for idx, (h, d) in enumerate(s1_items):
        p = t6_left.paragraphs[0] if idx == 0 else t6_left.add_paragraph()
        p.text = f"• {h}: {d}"
        p.font.name = "Arial"
        p.font.size = Pt(9.5)
        p.font.color.rgb = TEXT_DARK
        if idx > 0:
            p.space_before = Pt(6)

    add_card(slide6, Inches(6.85), Inches(2.7), w6_card, Inches(4.2), bg_color=CARD_BG, border_color=ACCENT_BLUE_DARK, border_width=2.0)
    add_pill_badge(slide6, Inches(7.15), Inches(2.9), Inches(3.8), Inches(0.32), "🧠 SYSTEM 2: GENERATIVE REASONING & SYNTHESIS", SUCCESS_GREEN_BG, ACCENT_BLUE_DARK)

    t6_right = slide6.shapes.add_textbox(Inches(7.15), Inches(3.35), w6_card - Inches(0.6), Inches(3.3)).text_frame
    t6_right.word_wrap = True
    s2_items = [
        ("Clinical Language Model", "Empathetic, medically accurate conversational framing strictly bounded by clinical facts."),
        ("SOCRATES Exploration Chips", "Generates targeted one-tap clarification chips (e.g., 'Pain is tight pressure', 'Started today')."),
        ("Calibrated Confidence Rating", "Calculates ECE confidence (0.0 to 1.0) and flags atypical symptoms for clinician human review."),
        ("Automated SOAP Note Generation", "Synthesizes structured Subjective, Objective, Assessment, Plan documentation for physician review.")
    ]
    for idx, (h, d) in enumerate(s2_items):
        p = t6_right.paragraphs[0] if idx == 0 else t6_right.add_paragraph()
        p.text = f"• {h}: {d}"
        p.font.name = "Arial"
        p.font.size = Pt(9.5)
        p.font.color.rgb = TEXT_DARK
        if idx > 0:
            p.space_before = Pt(6)

    # =========================================================================
    # SLIDE 7: CLOSED-LOOP TRIAGE & CLINICIAN SOAP NOTE
    # =========================================================================
    slide7 = prs.slides.add_slide(blank_layout)
    apply_background(slide7, BG_LIGHT)
    add_header(slide7, "Closed-Loop Triage & Physician SOAP Note Synthesis")

    card7 = add_card(slide7, Inches(0.8), Inches(1.55), Inches(11.733), Inches(3.3), bg_color=CARD_BG, border_color=PRIMARY_TEAL, border_width=1.5)
    add_pill_badge(slide7, Inches(1.05), Inches(1.75), Inches(3.6), Inches(0.32), "📋 AUTOMATED CLINICIAN SOAP NOTE", CARD_SUBTLE, PRIMARY_TEAL)

    tb7_soap = slide7.shapes.add_textbox(Inches(1.05), Inches(2.15), Inches(11.2), Inches(2.5)).text_frame
    tb7_soap.word_wrap = True

    soap_sections = [
        ("S (Subjective)", "Patient #391 reports via secure WhatsApp channel: 'hello doctor I have severe chest pain'. Chief complaint presented asynchronously. Acute onset."),
        ("O (Objective)", "Telemetry: Blood Pressure 150/95 mmHg, HR 82 BPM. Active EHR Comorbidities: Essential Hypertension, Type 2 Diabetes. Telemetry synced with Central AWS Cloud."),
        ("A (Assessment)", "Acuity: CTAS Level 2 (Emergent - Potential Threat to Life). Guideline Reference: Hypertension Canada Stage 2 + Cardiac Red Flag. Decision Engine Calibration Confidence: 98%."),
        ("P (Plan)", "STAT Escalation: Dispatched 911 alert. Flagged Dr. Patel on-call triage queue. Priority consultation slot confirmed (#APT-195).")
    ]
    for idx, (sec_title, sec_text) in enumerate(soap_sections):
        p = tb7_soap.paragraphs[0] if idx == 0 else tb7_soap.add_paragraph()
        p.text = f"{sec_title}: {sec_text}"
        p.font.name = "Arial"
        p.font.size = Pt(10)
        p.font.color.rgb = TEXT_DARK
        if idx > 0:
            p.space_before = Pt(4)

    w7_sub = Inches(3.68)
    gap7_sub = Inches(0.34)

    highlights = [
        ("1. Real Clinical Actions", "Replaces passive chatbot text with one-tap 911 dialing, urgent care check-in, and AWS appointment scheduling.", ALERT_RED),
        ("2. Calibrated Confidence", "Transparently scores decision calibration (98%) and flags atypical cases for human clinician oversight.", ACCENT_BLUE_DARK),
        ("3. Hospital Cloud Persistence", "Writes vitals, triage flags, and appointments directly into 72 normalized AWS eHospital database tables.", PRIMARY_TEAL)
    ]
    for idx, (title, desc, color) in enumerate(highlights):
        left_pos = Inches(0.8) + (w7_sub + gap7_sub) * idx
        add_card(slide7, left_pos, Inches(5.05), w7_sub, Inches(1.85), bg_color=CARD_BG, border_color=color, border_width=1.5)
        tb_sub = slide7.shapes.add_textbox(left_pos + Inches(0.2), Inches(5.15), w7_sub - Inches(0.4), Inches(1.6)).text_frame
        tb_sub.word_wrap = True
        p_t = tb_sub.paragraphs[0]
        p_t.text = title
        p_t.font.name = "Georgia"
        p_t.font.size = Pt(12)
        p_t.font.bold = True
        p_t.font.color.rgb = color
        p_d = tb_sub.add_paragraph()
        p_d.text = desc
        p_d.font.name = "Arial"
        p_d.font.size = Pt(9.5)
        p_d.font.color.rgb = TEXT_DARK
        p_d.space_before = Pt(3)

    out_file = "eHospital_Professional_Architecture_Slides.pptx"
    prs.save(out_file)
    print(f"Professional presentation saved successfully: {os.path.abspath(out_file)}")

if __name__ == "__main__":
    build_human_grade_deck()
