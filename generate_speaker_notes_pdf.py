"""Generate a clean, professional, readable PDF of presentation speaker notes
for Savage et al. (JAMIA 2025) integrated with Group 12's e-Hospital AI-Twin project.
"""

from pathlib import Path
from reportlab.lib.colors import HexColor
from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.pdfgen import canvas
from reportlab.platypus import (
    HRFlowable,
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)

PDF_OUTPUT = Path(
    r"c:\Users\sugan\OneDrive\Desktop\Hackers-Healers-1\Savage_2025_JAMIA_eHospital_Speaker_Notes.pdf"
)

# Color Palette
PRIMARY = HexColor("#0F2744")  # Deep Navy
SECONDARY = HexColor("#0D7377")  # Medical Teal
CYAN_ACCENT = HexColor("#0284C7")  # Clean Sky/Cyan
CORAL_ACCENT = HexColor("#DC2626")  # Alert Red/Coral
TEXT_DARK = HexColor("#1E293B")  # Slate 800
TEXT_MUTED = HexColor("#475569")  # Slate 600
BG_CARD = HexColor("#FFFFFF")  # Pure White
BG_PAGE = HexColor("#F8FAFC")  # Slate 50
BG_TIEIN = HexColor("#F0FDF4")  # Soft Emerald / Hospital Green
BORDER_CARD = HexColor("#CBD5E1")  # Slate 300
BORDER_TIEIN = HexColor("#86EFAC")  # Emerald 300


class NumberedCanvas(canvas.Canvas):
    """Two-pass canvas to dynamically compute and print 'Page X of Y'."""

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

    def draw_page_decorations(self, total_pages):
        self.saveState()
        self.setFont("Helvetica", 8.5)
        self.setFillColor(HexColor("#64748B"))

        # Running Header (pages > 1)
        if self._pageNumber > 1:
            self.setStrokeColor(HexColor("#E2E8F0"))
            self.setLineWidth(0.5)
            self.line(40, letter[1] - 32, letter[0] - 40, letter[1] - 32)
            self.drawString(
                40,
                letter[1] - 26,
                "BMG 5111 / ELG 6131 Graduate Seminar  |  Savage et al. (JAMIA 2025) & e-Hospital AI-Twin",
            )

        # Running Footer
        self.setStrokeColor(HexColor("#E2E8F0"))
        self.setLineWidth(0.5)
        self.line(40, 36, letter[0] - 40, 36)
        self.drawString(
            40,
            24,
            "Group 12: e-Hospital AI-Twin  |  University of Ottawa Fall 2026",
        )
        page_str = f"Page {self._pageNumber} of {total_pages}"
        self.drawRightString(letter[0] - 40, 24, page_str)
        self.restoreState()


def build_pdf():
    doc = SimpleDocTemplate(
        str(PDF_OUTPUT),
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=44,
        bottomMargin=46,
    )

    styles = getSampleStyleSheet()

    # Custom typography styles
    style_doc_title = ParagraphStyle(
        "DocTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=20,
        leading=24,
        textColor=PRIMARY,
        spaceAfter=4,
    )

    style_doc_sub = ParagraphStyle(
        "DocSub",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=11,
        leading=15,
        textColor=SECONDARY,
        spaceAfter=14,
    )

    style_badge = ParagraphStyle(
        "Badge",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=HexColor("#FFFFFF"),
        alignment=1,
    )

    style_slide_title = ParagraphStyle(
        "SlideTitle",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=13,
        leading=16,
        textColor=PRIMARY,
        spaceAfter=4,
    )

    style_label_bullets = ParagraphStyle(
        "LabelBullets",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=HexColor("#0369A1"),
        spaceAfter=0,
    )

    style_bullets = ParagraphStyle(
        "SlideBullets",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9.5,
        leading=13.5,
        textColor=TEXT_DARK,
        spaceAfter=4,
    )

    style_label_speech = ParagraphStyle(
        "LabelSpeech",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=HexColor("#92400E"),
        spaceAfter=0,
    )

    style_speech = ParagraphStyle(
        "SpeechText",
        parent=styles["Normal"],
        fontName="Helvetica-Oblique",
        fontSize=9.5,
        leading=13.5,
        textColor=HexColor("#1E293B"),
        spaceAfter=4,
    )

    style_label_tiein = ParagraphStyle(
        "LabelTieIn",
        parent=styles["Normal"],
        fontName="Helvetica-Bold",
        fontSize=8.5,
        leading=11,
        textColor=HexColor("#15803D"),
        spaceAfter=0,
    )

    style_tiein = ParagraphStyle(
        "TieInText",
        parent=styles["Normal"],
        fontName="Helvetica",
        fontSize=9.5,
        leading=13.5,
        textColor=HexColor("#14532D"),
    )

    slides_data = [
        {
            "num": "01",
            "title": "Title Slide: LLM Uncertainty Proxies in Clinical Practice",
            "bullets": (
                "• <b>Paper:</b> Savage et al., <i>JAMIA</i> 2025; 32(1):139–149.<br/>"
                "• <b>Core Question:</b> How do we know when medical AI is genuinely confident vs. hallucinating?<br/>"
                "• <b>Evaluation Scope:</b> 723 open-ended clinical questions, 4 LLMs, 24,941 physician-graded answers."
            ),
            "say": (
                "“Good morning everyone. Today I am presenting our review of Savage et al.’s 2025 JAMIA paper "
                "on LLM uncertainty. Large language models speak very fluently, but in medicine, sounding confident "
                "does not mean being correct. This paper investigates how to detect when an AI is guessing versus "
                "when it is reliable—an insight we apply directly to safe AI guardrails in our e-Hospital project.”"
            ),
            "project": (
                "<b>Project Tie-In (e-Hospital AI-Twin):</b> When our patient Robert Tremblay texts his vitals over WhatsApp, "
                "our local AI assistant must know its own limits before answering. This paper provides the exact "
                "foundation for deciding when our system should answer directly or escalate to a doctor."
            ),
        },
        {
            "num": "02",
            "title": "Research Question: Identifying When Clinical AI is Correct",
            "bullets": (
                "• <b>Real-World Need:</b> Multiple-choice tests don't reflect clinics; doctors and patients ask open-ended questions.<br/>"
                "• <b>Two Key Tasks:</b> Disease Diagnosis and Treatment Selection.<br/>"
                "• <b>Three Methods Tested:</b> Asking '% sure?' (Verbal), word math (Token Probs), and asking 15 times (Consistency)."
            ),
            "say": (
                "“The authors asked: In open-ended clinical cases, how can an AI measure if its answer is correct? "
                "They tested diagnosis and treatment selection, comparing three ways of measuring confidence: "
                "verbal self-ratings, token probabilities, and response agreement across repeated samples.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our project, Robert Tremblay asks if his blood pressure (138/86 mmHg) needs medication. "
                "Our backend must know if its proposed response is reliable before sending it to the patient."
            ),
        },
        {
            "num": "03",
            "title": "Discrimination vs. Calibration: Smoke Alarm vs. Weather Forecast",
            "bullets": (
                "• <b>Discrimination (ROC AUC ≥ 0.70):</b> Can the score tell right answers from wrong answers? (The Smoke Alarm).<br/>"
                "• <b>Calibration (ECE & Brier Score):</b> Does the confidence % match reality? (The Weather Forecast).<br/>"
                "• <b>The Clinical Trap:</b> An AI can claim 99% certainty on an answer that is only 80% accurate."
            ),
            "say": (
                "“Think of discrimination as a smoke alarm: it doesn't care about exact numbers, it just rings when "
                "an answer is wrong so we can trigger guidelines. Calibration is an honest weather forecast: if AI says "
                "‘80% sure’, it must be right 8 out of 10 times. You can have a great smoke alarm with completely misleading percentages.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> We use <i>discrimination</i> to trigger Selective RAG (retrieving clinical guidelines). "
                "We use <i>calibration</i> before displaying any risk scores to doctors on our e-Hospital dashboard."
            ),
        },
        {
            "num": "04",
            "title": "Models and Datasets: 723 Open-Ended Cases Across 4 LLMs",
            "bullets": (
                "• <b>723 Questions:</b> 418 MedQA exam cases, 200 tough NEJM mystery cases, 105 Stanford clinical vignettes.<br/>"
                "• <b>4 Models:</b> GPT-4, GPT-3.5-turbo, open-weight Llama2-70B, and Llama3-70B (run on 2× A100 GPUs).<br/>"
                "• <b>Free-Text Design:</b> All multiple-choice options were removed to simulate real doctor consultations."
            ),
            "say": (
                "“The researchers tested 723 real clinical cases with the multiple-choice options stripped out. "
                "They ran GPT-4 and GPT-3.5 alongside open-source Llama2 and Llama3 models running locally on A100 GPUs.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> Testing open-weight models (like Llama) is essential for our Canadian hospital system. "
                "Under Ontario's PHIPA privacy laws, patient health information cannot be sent to public cloud APIs; "
                "it must run on secure, on-premise local models like Ollama in our e-Hospital stack."
            ),
        },
        {
            "num": "05",
            "title": "Confidence Elicitation: Asking '% Sure?' Fails in Healthcare",
            "bullets": (
                "• <b>One-Step vs. Two-Step:</b> Prompting the AI to state its certainty (0–100%) alongside or after its answer.<br/>"
                "• <b>Fatal Flaw:</b> LLMs are sycophantic; they routinely claim 85%–95% confidence even on dead-wrong answers.<br/>"
                "• <b>Result:</b> Discrimination stayed below 0.64 AUC, failing the 0.70 clinical safety threshold."
            ),
            "say": (
                "“The simplest method is asking the AI: ‘How sure are you from 0 to 100%?’. The paper proved this fails. "
                "Because of human-feedback training, models are polite and boastful—they say 90% confidence even when their "
                "medical reasoning is completely incorrect.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our e-Hospital AI-Twin, we never ask the chatbot ‘Are you confident?’. "
                "Verbal self-confidence is an illusion and cannot be used as a medical safety gate."
            ),
        },
        {
            "num": "06",
            "title": "Token-Level Probabilities: Internal Math is Too Fragile",
            "bullets": (
                "• <b>Word Probability Math:</b> Tracking probabilities of output tokens (e.g., ‘Levo-flox-a-cin’).<br/>"
                "• <b>Two Scores:</b> Average probability across tokens vs. Minimum probability (the weakest link).<br/>"
                "• <b>Practical Hurdle:</b> Sensitive to phrasing differences, and modern closed APIs (OpenAI) block access to raw log-probs."
            ),
            "say": (
                "“The second method checks internal math—the probability of each word generated. But minor wording changes "
                "skew the math, and commercial APIs increasingly hide these probabilities from healthcare developers.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> Because our e-Hospital uses lightweight quantized local models (Ollama gemma2:2b), "
                "extracting token log-probabilities is brittle. We need a model-agnostic method that works from text alone."
            ),
        },
        {
            "num": "07",
            "title": "Sample Consistency: The Breakthrough (Ask 15 Times)",
            "bullets": (
                "• <b>Core Intuition:</b> If AI knows the medicine, repeated tries agree. If it's guessing, answers scatter.<br/>"
                "• <b>Protocol:</b> Generate 15 stochastic completions at temperatures 0.5 and 1.0.<br/>"
                "• <b>Measuring Agreement:</b> GPT-4 semantic judge vs. sentence embeddings (PubMedBERT and e5)."
            ),
            "say": (
                "“The winning method is Sample Consistency: ask the AI 15 times. On the slide, 4/12 agreement means guessing, "
                "while 8/12 agreement means real confidence. When an AI hallucinates, it invents different stories each time; "
                "when it has solid medical knowledge, its answers converge.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our backend, consistency across sampled clinical drafts provides our primary "
                "signal for whether the AI understands Robert Tremblay's case or is hallucinating."
            ),
        },
        {
            "num": "08",
            "title": "Physician Grading: 24,941 Answers Verified by Doctors",
            "bullets": (
                "• <b>Doctor Ground Truth:</b> Two blinded physicians graded 24,941 answers (93% agreement, Cohen’s κ = 0.85).<br/>"
                "• <b>Clinical References:</b> Graded against UpToDate, MKSAP 19, and StatPearls.<br/>"
                "• <b>Statistical Rigor:</b> 4,000 bootstrap iterations; calibration checked on models reaching ROC AUC ≥ 0.70."
            ),
            "say": (
                "“The authors didn't rely on simple keyword matching. Two board-certified doctors independently graded "
                "nearly 25,000 answers against medical references with 93% agreement. This gives us immense confidence in the data.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> Just like this paper used physician ground truth, our project grounds every AI "
                "decision in official Canadian medical guidelines (Hypertension Canada and Diabetes Canada 2026)."
            ),
        },
        {
            "num": "09",
            "title": "Baseline Accuracy: Tough Mystery Cases Expose AI Limits",
            "bullets": (
                "• <b>NEJM Mystery Cases:</b> Extremely difficult (GPT-4 = 32%, Llama3 = 26%, Llama2 = 14%).<br/>"
                "• <b>Standard MedQA:</b> GPT-4 reached 69%, Llama3 48%, GPT-3.5 49%.<br/>"
                "• <b>The Lesson:</b> Zero-shot clinical AI fails frequently; uncertainty detection is mandatory."
            ),
            "say": (
                "“Looking at raw accuracy, NEJM mystery cases were brutal: even GPT-4 only scored 32%. Because LLMs "
                "are far from 100% accurate, an automated uncertainty safety net is not optional—it is life or death.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> Robert Tremblay has comorbid hypertension and pre-diabetes (glucose 6.8 mmol/L). "
                "Because multi-condition patients are complex, our AI must never assume it is right without checking guidelines."
            ),
        },
        {
            "num": "10",
            "title": "Results: Discrimination (Diagnosis vs. Treatment)",
            "bullets": (
                "• <b>Diagnosis Peak:</b> GPT-4 reached 0.79 ROC AUC and GPT-3.5 hit 0.77 using Sample Consistency.<br/>"
                "• <b>Treatment is Harder:</b> Llama3 led with 0.75 AUC, GPT-4 hit 0.71, while Llama2 collapsed (0.46–0.56).<br/>"
                "• <b>Big Insight:</b> Catching wrong treatments is significantly harder than catching wrong diagnoses."
            ),
            "say": (
                "“Sample Consistency easily crossed the 0.70 clinical utility bar for diagnosis, with GPT-4 hitting 0.79. "
                "However, treatment selection was much harder: Llama3 hit 0.75, GPT-4 hit 0.71, and Llama2 dropped near coin-flipping. "
                "Checking treatment accuracy is universally harder than diagnosing illnesses.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our project, Robert's diagnosis (Stage 1 Hypertension) is easy to confirm. But picking "
                "his treatment (lifestyle vs. ACE inhibitor vs. ARB) has multiple options. That is why our AI never prescribes drugs autonomously."
            ),
        },
        {
            "num": "11",
            "title": "Calibration: The Hidden Embedding Trap (Figure 7)",
            "bullets": (
                "• <b>The Honest Diagonal:</b> The dashed line represents perfect honesty (predicted % = real accuracy).<br/>"
                "• <b>GPT Judge Calibrates Best:</b> Closely tracks the diagonal line (ECE = 0.09, Brier = 0.21).<br/>"
                "• <b>The Embedding Trap:</b> Embeddings cluster at 85%–98% similarity, giving false confidence (ECE = 0.38–0.52)."
            ),
            "say": (
                "“This is the most critical visual in the paper. The dashed diagonal is honesty. Green GPT judge tracks honesty "
                "remarkably well. But look at blue sentence embeddings: because medical sentences share vocabulary, embeddings "
                "give 90% similarity even when the clinical answer is completely wrong! Their raw scores look deceptively confident.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our e-Hospital UI, we never show raw cosine similarity scores to patients or doctors. "
                "Showing uncalibrated 90% numbers creates dangerous false reassurance."
            ),
        },
        {
            "num": "12",
            "title": "Summary Comparison: One Size Does Not Fit All",
            "bullets": (
                "• <b>Sentence Embeddings:</b> Best smoke alarm (high ROC AUC), but terrible weather forecast (poor calibration).<br/>"
                "• <b>GPT Annotation:</b> Great smoke alarm + honest weather forecast (strong AUC and low ECE).<br/>"
                "• <b>Verbal Confidence:</b> Fails both tests (overconfident and poor discrimination)."
            ),
            "say": (
                "“To summarize: sentence embeddings are great for automated triggers, but terrible for human display. "
                "GPT annotation provides the best overall balance. Never assume a high ranking score means an honest percentage.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> We use embedding consistency internally to trigger guideline retrieval, "
                "but keep the raw math hidden from users."
            ),
        },
        {
            "num": "13",
            "title": "Why Treatment is Harder: Therapeutic Pluralism",
            "bullets": (
                "• <b>One Diagnosis, Multiple Treatments:</b> Medicine often has one true diagnosis, but several valid therapies.<br/>"
                "• <b>False Disagreement:</b> Lisinopril, Losartan, or Amlodipine are all guideline-correct for hypertension.<br/>"
                "• <b>The Artifact:</b> Sampling 15 times looks like 'disagreement' to math, even though all 3 are medically sound."
            ),
            "say": (
                "“Why did treatment selection score worse? Because of therapeutic pluralism. If an AI suggests Lisinopril "
                "on try 1 and Losartan on try 2, the math counts that as disagreement, even though both are guideline-approved. "
                "Valid clinical variety lowers the consistency score.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> For Robert Tremblay's hypertension, our AI presents all valid guideline options "
                "to the physician alongside OHIP billing codes (A007 / K013), leaving the final selection to human judgment."
            ),
        },
        {
            "num": "14",
            "title": "Real-World Limitations: The 15× Latency Barrier",
            "bullets": (
                "• <b>15× Cost & Delay:</b> Generating 15 completions is too slow and expensive for interactive WhatsApp chat.<br/>"
                "• <b>Static vs. Real EHR:</b> Real clinics have multi-turn patient questions, lab noise, and drug allergies.<br/>"
                "• <b>Privacy Rules (PHIPA):</b> Calling third-party cloud judges leaks patient data outside Canadian borders."
            ),
            "say": (
                "“The big limitation of Savage et al. is speed: running 15 samples plus a judge takes 15 times longer and costs 15 times more. "
                "A patient on WhatsApp will not wait 30 seconds for a reply. Furthermore, shipping patient text to external cloud APIs "
                "violates Canadian health privacy laws.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> This exact latency and privacy barrier shaped our e-Hospital architecture: we use local "
                "on-premise models, lightweight sampling, and Selective RAG to keep chat instant and private."
            ),
        },
        {
            "num": "15",
            "title": "Conclusions & The RLHF Dilemma (Why AI Sounds Too Confident)",
            "bullets": (
                "• <b>Sample Consistency Wins:</b> Agreement across repeated samples is the only reliable error detector.<br/>"
                "• <b>The RLHF Trap:</b> Standard Reinforcement Learning from Human Feedback rewards assertive answers, penalizing hedging.<br/>"
                "• <b>The 15× Problem:</b> Post-hoc sampling works, but it's 15× too slow and costly for real-time mobile chat."
            ),
            "say": (
                "“To conclude the paper's findings: Sample consistency is our best error detector today. But why did verbal "
                "confidence fail so miserably? The answer is RLHF—Reinforcement Learning from Human Feedback. Human raters "
                "prefer helpful, confident-sounding answers, so standard LLMs are literally trained to be boastful and hide doubt. "
                "To catch errors, Savage et al. had to sample 15 times—which creates a 15× latency and cost bottleneck.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> In our e-Hospital, we cannot tolerate a 30-second delay on WhatsApp, nor can we trust "
                "RLHF-trained boastful answers. We need a way to make uncertainty fast and honest in a single step."
            ),
        },
        {
            "num": "16",
            "title": "The Alignment Horizon: RLVR, RLCD & Jev Typed Architecture",
            "bullets": (
                "• <b>RLVR (Verifiable Rewards):</b> Trains reasoning against hard medical facts (lab cutoffs, ICD codes, e.g. EHRMIND).<br/>"
                "• <b>RLCD (Context Distillation):</b> Bakes safety rules (‘abstain if risk > threshold’) into 1 fast forward pass.<br/>"
                "• <b>Jev (Typed Safety):</b> Enforces strict schema constraints, typed JSON outputs, and structured abstention."
            ),
            "say": (
                "“This brings us to modern AI alignment: How do we fix this without paying a 15× compute tax? "
                "First, **RLVR** (Reinforcement Learning from Verifiable Rewards): instead of human opinions, the model is "
                "rewarded by clinical facts like blood pressure ranges and dosing rules. "
                "Second, **RLCD** (Context Distillation): safety rules like ‘when uncertain, say you don't know’ are baked directly "
                "into the model's weights. "
                "And third, **Jev**: a typed safety architecture that forces the AI to output verified structured fields rather "
                "than rambling prose, ensuring calibrated abstention in one instant pass.”"
            ),
            "project": (
                "<b>Project Tie-In:</b> Instead of 15 slow retries, our e-Hospital AI-Twin uses Jev-style typed schemas "
                "and RLCD rules: if uncertainty is triggered, the AI is constrained to a typed abstention object that auto-invokes "
                "Selective RAG over Canadian guidelines."
            ),
        },
        {
            "num": "17",
            "title": "Reference & System Architecture: The e-Hospital AI-Twin",
            "bullets": (
                "• <b>Reference:</b> Savage et al., <i>JAMIA</i> 2025; 32(1):139–149. DOI: 10.1093/jamia/ocae254.<br/>"
                "• <b>1. Selective RAG:</b> Retrieve Canadian guidelines only when uncertainty exceeds calibrated threshold.<br/>"
                "• <b>2. Jev Guardrails:</b> Strict typed JSON schema prevents hallucinations and forces structured outputs.<br/>"
                "• <b>3. Doctor Sign-Off:</b> Treatment and OHIP billing (A007/K013) remain strictly physician-gated."
            ),
            "say": (
                "“To wrap up, here is how Savage et al., RLVR, RLCD, and Jev come together in our Group 12 e-Hospital AI-Twin: "
                "Robert Tremblay texts his vitals over WhatsApp. The readings convert to an HL7 FHIR Observation. "
                "Our local on-premise model evaluates the case with Jev typed safety. If uncertainty is flagged, Selective RAG "
                "retrieves Hypertension and Diabetes Canada guidelines. Finally, the proposed plan is sent to the physician’s dashboard "
                "with OHIP billing codes A007 and K013 for human approval. "
                "Thank you, and I look forward to your questions!”"
            ),
            "project": (
                "<b>Project Tie-In (Complete Pipeline):</b> WhatsApp Vitals (BP 138/86, Glucose 6.8) → FHIR R4 → "
                "Local AI with Jev Typed Safety → Selective RAG (Canadian Guidelines) → Physician Review & OHIP Billing. "
                "A complete, safe, calibrated telemedicine solution.”"
            ),
        },
    ]

    story = []

    # Title Banner Block
    banner_data = [
        [
            Paragraph("BMG 5111 / ELG 6131 Graduate Seminar: Speaker Notes", style_doc_title),
        ],
        [
            Paragraph(
                "<b>Paper:</b> Savage et al. (JAMIA 2025; 32(1):139–149)  |  <b>Project:</b> Group 12 e-Hospital AI-Twin (Fall 2026)<br/>"
                "<i>Clean, conversational slide-by-slide notes with key bullet points, spoken script, and project tie-ins.</i>",
                style_doc_sub,
            ),
        ],
    ]
    t_banner = Table(banner_data, colWidths=[7.2 * inch])
    t_banner.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), HexColor("#F1F5F9")),
                ("BOX", (0, 0), (-1, -1), 1.0, HexColor("#CBD5E1")),
                ("LEFTPADDING", (0, 0), (-1, -1), 14),
                ("RIGHTPADDING", (0, 0), (-1, -1), 14),
                ("TOPPADDING", (0, 0), (-1, -1), 10),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    story.append(t_banner)
    story.append(Spacer(1, 10))

    # Add each slide as a clean, structured card
    for i, item in enumerate(slides_data):
        slide_card_data = [
            # Header Row
            [
                Paragraph(f"SLIDE {item['num']}", style_badge),
                Paragraph(item["title"], style_slide_title),
            ],
            # Bullets Row
            [
                Paragraph("<b>SLIDE<br/>POINTS</b>", style_label_bullets),
                Paragraph(item["bullets"], style_bullets),
            ],
            # Spoken Script Row
            [
                Paragraph("<b>WHAT<br/>TO SAY</b>", style_label_speech),
                Paragraph(item["say"], style_speech),
            ],
            # Project Tie-In Row
            [
                Paragraph("<b>PROJECT<br/>TIE-IN</b>", style_label_tiein),
                Paragraph(item["project"], style_tiein),
            ],
        ]

        t_slide = Table(
            slide_card_data,
            colWidths=[1.15 * inch, 6.20 * inch],
        )
        t_slide.setStyle(
            TableStyle(
                [
                    # Outer Card Border
                    ("BOX", (0, 0), (-1, -1), 1.0, BORDER_CARD),
                    # Header Row Styling
                    ("BACKGROUND", (0, 0), (0, 0), PRIMARY),
                    ("BACKGROUND", (1, 0), (1, 0), HexColor("#F8FAFC")),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 6),
                    ("TOPPADDING", (0, 0), (-1, 0), 6),
                    # Bullets Row Styling
                    ("BACKGROUND", (0, 1), (-1, 1), HexColor("#FFFFFF")),
                    ("LINEBELOW", (0, 0), (-1, 0), 0.5, BORDER_CARD),
                    ("LINEBELOW", (0, 1), (-1, 1), 0.5, HexColor("#E2E8F0")),
                    # Speech Row Styling
                    ("BACKGROUND", (0, 2), (-1, 2), HexColor("#FFFBEB")),  # Soft warm amber
                    ("LINEBELOW", (0, 2), (-1, 2), 0.5, HexColor("#FDE68A")),
                    # Project Tie-In Row Styling
                    ("BACKGROUND", (0, 3), (-1, 3), BG_TIEIN),  # Soft medical green
                    # Padding & Alignment
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 8),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ("TOPPADDING", (0, 1), (-1, -1), 6),
                    ("BOTTOMPADDING", (0, 1), (-1, -1), 6),
                ]
            )
        )

        story.append(KeepTogether(t_slide))
        story.append(Spacer(1, 11))

    # Build document
    doc.build(story, canvasmaker=NumberedCanvas)
    return PDF_OUTPUT


if __name__ == "__main__":
    out = build_pdf()
    print(f"Generated PDF: {out} ({out.stat().st_size:,} bytes)")
