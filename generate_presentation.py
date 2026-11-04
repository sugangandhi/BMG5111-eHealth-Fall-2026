import sys
import os
from pptx import Presentation
from pptx.util import Inches, Pt
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.enum.shapes import MSO_SHAPE

def create_deck():
    prs = Presentation()
    prs.slide_width = Inches(13.333)
    prs.slide_height = Inches(7.5)
    blank_layout = prs.slide_layouts[6] # blank layout

    # Color Palette - Professional Medical Academic
    BG_DARK = RGBColor(15, 23, 42)      # Slate 900
    BG_LIGHT = RGBColor(248, 250, 252)  # Slate 50
    CARD_BG = RGBColor(255, 255, 255)   # White
    CARD_BORDER = RGBColor(226, 232, 240) # Slate 200
    
    PRIMARY_TEAL = RGBColor(13, 148, 136) # Teal 600
    ACCENT_BLUE = RGBColor(14, 165, 233)  # Sky 500
    TEXT_DARK = RGBColor(30, 41, 59)      # Slate 800
    TEXT_MUTED = RGBColor(100, 116, 139)  # Slate 500
    TEXT_LIGHT = RGBColor(241, 245, 249)  # Slate 100
    HIGHLIGHT_RED = RGBColor(225, 29, 72) # Rose 600
    HIGHLIGHT_AMBER = RGBColor(217, 119, 6) # Amber 600
    HIGHLIGHT_GREEN = RGBColor(22, 163, 74) # Green 600

    def add_header(slide, title, category="RESEARCH SEMINAR | BMG 5111 / eHEALTH & mHEALTH"):
        header_box = slide.shapes.add_textbox(Inches(0.8), Inches(0.4), Inches(11.733), Inches(0.9))
        tf = header_box.text_frame
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

    # ==========================================
    # SLIDE 1: TITLE SLIDE (Dark Academic Theme)
    # ==========================================
    slide1 = prs.slides.add_slide(blank_layout)
    bg1 = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, 0, 0, Inches(13.333), Inches(7.5))
    bg1.fill.solid()
    bg1.fill.fore_color.rgb = BG_DARK
    bg1.line.fill.background()

    bar = slide1.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(1.2), Inches(0.15), Inches(4.8))
    bar.fill.solid()
    bar.fill.fore_color.rgb = PRIMARY_TEAL
    bar.line.fill.background()

    tbox1 = slide1.shapes.add_textbox(Inches(1.4), Inches(1.2), Inches(10.8), Inches(4.8))
    tf1 = tbox1.text_frame
    tf1.word_wrap = True

    p = tf1.paragraphs[0]
    p.text = "JOURNAL OF THE AMERICAN MEDICAL INFORMATICS ASSOCIATION (JAMIA 2025)"
    p.font.name = "Arial"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE

    p = tf1.add_paragraph()
    p.text = "Large Language Model Uncertainty Proxies:\nDiscrimination and Calibration for Medical Diagnosis and Treatment"
    p.font.name = "Georgia"
    p.font.size = Pt(26)
    p.font.bold = True
    p.font.color.rgb = TEXT_LIGHT
    p.space_before = Pt(12)

    p = tf1.add_paragraph()
    p.text = "Thomas Savage, MD, John Wang, MD, Robert Gallo, MD, ..., Jonathan H. Chen, MD, PhD"
    p.font.name = "Arial"
    p.font.size = Pt(13)
    p.font.color.rgb = RGBColor(203, 213, 225)
    p.space_before = Pt(16)

    p = tf1.add_paragraph()
    p.text = "Stanford Center for Biomedical Informatics Research (BMIR) | JAMIA, 32(1): 139–149 (2025)"
    p.font.name = "Arial"
    p.font.size = Pt(11)
    p.font.italic = True
    p.font.color.rgb = PRIMARY_TEAL
    p.space_before = Pt(4)

    p = tf1.add_paragraph()
    p.text = "Presenter: Graduate Student Seminar | BMG 5111 / ELG 6131 / DTI 6302 (eHealth, mHealth & Telemedicine)\nFaculty of Engineering, University of Ottawa"
    p.font.name = "Arial"
    p.font.size = Pt(12)
    p.font.color.rgb = RGBColor(148, 163, 184)
    p.space_before = Pt(28)

    # ==========================================
    # SLIDE 2: EXECUTIVE SUMMARY & CORE TAKEAWAYS
    # ==========================================
    slide2 = prs.slides.add_slide(blank_layout)
    add_header(slide2, "Executive Summary: Key Findings at a Glance")

    c1 = add_card(slide2, Inches(0.8), Inches(1.6), Inches(3.7), Inches(5.2))
    t1 = slide2.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(3.3), Inches(4.8)).text_frame
    t1.word_wrap = True
    p = t1.paragraphs[0]
    p.text = "1. THE PROBLEM"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t1.add_paragraph()
    p.text = "Severe Overconfidence"
    p.font.size = Pt(18)
    p.font.bold = True
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(4)
    p = t1.add_paragraph()
    p.text = "• LLMs achieve near-physician exam accuracy, but cannot reliably express uncertainty.\n\n• Verbalized Confidence (asking the LLM how sure it is) consistently overestimates true accuracy, creating dangerous clinical liabilities.\n\n• Selective RAG deployment requires true uncertainty signals to prevent context pollution."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_MUTED
    p.space_before = Pt(12)

    c2 = add_card(slide2, Inches(4.8), Inches(1.6), Inches(3.7), Inches(5.2))
    t2 = slide2.shapes.add_textbox(Inches(5.0), Inches(1.8), Inches(3.3), Inches(4.8)).text_frame
    t2.word_wrap = True
    p = t2.paragraphs[0]
    p.text = "2. THE BENCHMARK"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t2.add_paragraph()
    p.text = "Sample Consistency Leads"
    p.font.size = Pt(18)
    p.font.bold = True
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(4)
    p = t2.add_paragraph()
    p.text = "• Evaluated 24,941 physician-graded answers across 4 LLMs (GPT-4, GPT-3.5, Llama 2/3) and 3 clinical datasets (MedQA, NEJM, Stanford).\n\n• Sample Consistency (SC: 15 stochastic forward passes) dramatically outperformed token probabilities and confidence elicitation in discrimination (ROC AUC 0.68–0.79)."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_MUTED
    p.space_before = Pt(12)

    c3 = add_card(slide2, Inches(8.8), Inches(1.6), Inches(3.7), Inches(5.2))
    t3 = slide2.shapes.add_textbox(Inches(9.0), Inches(1.8), Inches(3.3), Inches(4.8)).text_frame
    t3.word_wrap = True
    p = t3.paragraphs[0]
    p.text = "3. THE IMPLICATION"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t3.add_paragraph()
    p.text = "Calibration Mandate"
    p.font.size = Pt(18)
    p.font.bold = True
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(4)
    p = t3.add_paragraph()
    p.text = "• Discrimination ≠ Calibration. Sentence embeddings discriminate well but cluster at 0.8–1.0 (poor calibration).\n\n• SC via GPT Annotation achieved optimal calibration (lowest ECE & Brier score).\n\n• Explains why modern eHealth needs RLCD (Reinforcement Learning for Calibrated Decisions) for safe triage."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_MUTED
    p.space_before = Pt(12)

    # ==========================================
    # SLIDE 3: CLINICAL MOTIVATION
    # ==========================================
    slide3 = prs.slides.add_slide(blank_layout)
    add_header(slide3, "Clinical Motivation: The 'Confident Hallucination' Danger")

    add_card(slide3, Inches(0.8), Inches(1.6), Inches(5.7), Inches(5.2))
    tb3_1 = slide3.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    tb3_1.word_wrap = True
    p = tb3_1.paragraphs[0]
    p.text = "Why Clinical Uncertainty is Non-Negotiable"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = tb3_1.add_paragraph()
    p.text = "• Irreversible Medical Consequences: In medicine, recommendations dictate invasive biopsies, medication titration, or emergency surgery. An uncertain model acting confident causes medical malpractice."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)
    p = tb3_1.add_paragraph()
    p.text = "• The 'Premature Diagnostic Closure' Trap: When an AI asserts 99% certainty on a differential diagnosis that only has an 80% true probability, busy physicians fail to explore alternative, life-threatening pathologies."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)
    p = tb3_1.add_paragraph()
    p.text = "• The eHealth / Telemedicine Scaling Bottleneck: Autonomous triage (e.g., patient SMS/WhatsApp) cannot proceed safely without a calibrated safety threshold for human escalation."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    add_card(slide3, Inches(6.8), Inches(1.6), Inches(5.7), Inches(5.2))
    tb3_2 = slide3.shapes.add_textbox(Inches(7.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    tb3_2.word_wrap = True
    p = tb3_2.paragraphs[0]
    p.text = "The RAG Deployment Paradox"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = tb3_2.add_paragraph()
    p.text = "• Retrieval-Augmented Generation (RAG) is designed to ground LLMs in external guidelines (e.g., Hypertension Canada, UpToDate)."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)
    p = tb3_2.add_paragraph()
    p.text = "• The Paradox (Labruna et al., 2024): Deploying RAG on every query introduces noise and context pollution. If an LLM already knows the answer, injecting unneeded passages often leads it into an errant answer!"
    p.font.size = Pt(12)
    p.font.color.rgb = HIGHLIGHT_RED
    p.space_before = Pt(10)
    p = tb3_2.add_paragraph()
    p.text = "• Solution: Selective RAG. RAG must only trigger when the model's internal uncertainty crosses a validated threshold. Hence, measuring uncertainty is a prerequisite for robust medical RAG."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    # ==========================================
    # SLIDE 4: THEORETICAL FOUNDATION: DISCRIMINATION VS CALIBRATION
    # ==========================================
    slide4 = prs.slides.add_slide(blank_layout)
    add_header(slide4, "Theoretical Framework: Discrimination vs. Calibration")

    add_card(slide4, Inches(0.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t4_1 = slide4.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t4_1.word_wrap = True
    p = t4_1.paragraphs[0]
    p.text = "DISCRIMINATION (Relative Ranking)"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t4_1.add_paragraph()
    p.text = "• Definition: How well the uncertainty metric separates correct answers from incorrect answers.\n\n• Statistical Metric: Receiver Operating Characteristic Area Under the Curve (ROC AUC) using 4,000 bootstrap iterations.\n\n• Clinical Significance: Answers: 'Is the model more confident on questions it actually gets right?'\n\n• Acceptance Threshold: ROC AUC ≥ 0.70 defines clinically useful discrimination (Mandrekar, 2010)."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(12)

    add_card(slide4, Inches(6.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t4_2 = slide4.shapes.add_textbox(Inches(7.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t4_2.word_wrap = True
    p = t4_2.paragraphs[0]
    p.text = "CALIBRATION (Absolute Reliability)"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t4_2.add_paragraph()
    p.text = "• Definition: Whether the predicted numerical confidence matches the observed empirical probability of correctness.\n\n• Statistical Metrics:\n   1. Expected Calibration Error (ECE) across 10 bins\n   2. Brier Score: Mean squared error between prediction & outcome\n   3. Calibration Curves (Observed vs. Predicted)\n\n• The Clinical Danger: A model can have great discrimination (ROC AUC 0.85) but terrible calibration (clustering at 99%). Clinicians require reliable calibration to set automated escalation gates."
    p.font.size = Pt(12)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(12)

    # ==========================================
    # SLIDE 5: METHODOLOGY & EXPERIMENTAL SETUP
    # ==========================================
    slide5 = prs.slides.add_slide(blank_layout)
    add_header(slide5, "Experimental Architecture & Dataset Scale")

    w = Inches(2.75)
    gap = Inches(0.2)
    
    add_card(slide5, Inches(0.8), Inches(1.6), w, Inches(5.2))
    t5_1 = slide5.shapes.add_textbox(Inches(0.9), Inches(1.8), w - Inches(0.2), Inches(4.8)).text_frame
    t5_1.word_wrap = True
    p = t5_1.paragraphs[0]
    p.text = "3 CLINICAL DATASETS\n(723 Total Scenarios)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t5_1.add_paragraph()
    p.text = "1. MedQA (USMLE):\n• 418 questions (179 Diagnosis, 239 Treatment).\n• Converted from Multiple Choice to OPEN-ENDED to simulate real clinical encounters!\n\n2. NEJM Case Records:\n• 200 real-world complex diagnostic challenges.\n\n3. Stanford Dataset:\n• 105 general internal medicine cases written by board-certified physicians."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide5, Inches(0.8) + w + gap, Inches(1.6), w, Inches(5.2))
    t5_2 = slide5.shapes.add_textbox(Inches(0.9) + w + gap, Inches(1.8), w - Inches(0.2), Inches(4.8)).text_frame
    t5_2.word_wrap = True
    p = t5_2.paragraphs[0]
    p.text = "4 LLM BACKBONES\n(Open & Closed)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t5_2.add_paragraph()
    p.text = "Frontier Closed Models:\n• GPT-4 (gpt-4-0613)\n• GPT-3.5 (gpt-3.5-turbo-0125)\n\nLeading Open Weights:\n• Llama 2-70B Chat\n• Llama 3-70B Instruct\n(Hosted on dedicated 2x A100 GPUs)\n\nTemperature Grid:\nTested at T = 0, 0.5, 1.0 (SC evaluated at 0.5 and 1.0 to ensure stochastic diversity)."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide5, Inches(0.8) + (w + gap)*2, Inches(1.6), w, Inches(5.2))
    t5_3 = slide5.shapes.add_textbox(Inches(0.9) + (w + gap)*2, Inches(1.8), w - Inches(0.2), Inches(4.8)).text_frame
    t5_3.word_wrap = True
    p = t5_3.paragraphs[0]
    p.text = "PHYSICIAN GRADING\n(24,941 Answers)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_AMBER
    p = t5_3.add_paragraph()
    p.text = "• Massive Scale: 26,208 total responses generated; 24,941 graded after excluding context errors.\n\n• Rigorous Blinded Review: 2 independent blinded physician annotators graded each response.\n\n• Third-Physician Tiebreaker: Discrepancies adjudicated by a third senior physician.\n\n• Verification: Benchmarked against UpToDate, MKSAP, and StatPearls."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide5, Inches(0.8) + (w + gap)*3, Inches(1.6), w, Inches(5.2))
    t5_4 = slide5.shapes.add_textbox(Inches(0.9) + (w + gap)*3, Inches(1.8), w - Inches(0.2), Inches(4.8)).text_frame
    t5_4.word_wrap = True
    p = t5_4.paragraphs[0]
    p.text = "EVALUATION PIPELINE\n(Discrim. & Calibration)"
    p.font.size = Pt(12)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN
    p = t5_4.add_paragraph()
    p.text = "Step 1: 15 Forward Passes\nRecord responses across 6 uncertainty proxies.\n\nStep 2: Discrimination\nCompute ROC AUC with 4,000 bootstrapped 95% CIs.\n\nStep 3: Gating Filter\nOnly proxies meeting ROC AUC ≥ 0.70 advance to calibration analysis.\n\nStep 4: Calibration Metrics\nCalibration curves, 10-bin ECE, and Brier scoring."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    # ==========================================
    # SLIDE 6: THE 3 UNCERTAINTY PROXIES
    # ==========================================
    slide6 = prs.slides.add_slide(blank_layout)
    add_header(slide6, "Deep Dive: The Three Uncertainty Proxy Families")

    w3 = Inches(3.7)
    gap3 = Inches(0.3)

    add_card(slide6, Inches(0.8), Inches(1.6), w3, Inches(5.2))
    t6_1 = slide6.shapes.add_textbox(Inches(1.0), Inches(1.8), w3 - Inches(0.4), Inches(4.8)).text_frame
    t6_1.word_wrap = True
    p = t6_1.paragraphs[0]
    p.text = "1. CONFIDENCE ELICITATION (CE)"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t6_1.add_paragraph()
    p.text = "SinglePass: Direct Prompting"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t6_1.add_paragraph()
    p.text = "• Approach: Asking the model directly to verbalize uncertainty on a 0–100 scale.\n\n• Two-Step CE: Step 1 generates clinical answer; Step 2 resubmits the full question-response pair asking for a confidence rating.\n\n• Advantage: Cheap, single-pass.\n\n• Fatal Flaw: Severe, systematic overconfidence. Models verbalize 90%+ confidence on blatantly incorrect diagnoses."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    add_card(slide6, Inches(0.8) + w3 + gap3, Inches(1.6), w3, Inches(5.2))
    t6_2 = slide6.shapes.add_textbox(Inches(1.0) + w3 + gap3, Inches(1.8), w3 - Inches(0.4), Inches(4.8)).text_frame
    t6_2.word_wrap = True
    p = t6_2.paragraphs[0]
    p.text = "2. TOKEN-LEVEL PROBABILITIES"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_AMBER
    p = t6_2.add_paragraph()
    p.text = "SinglePass: Internal Log-Probs"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t6_2.add_paragraph()
    p.text = "• Approach: Mathematical extraction of the model's generated token probabilities.\n\n• Metrics Analyzed:\n   1. Average token probability across the answer string.\n   2. Minimum token probability (identifying weak-link reasoning tokens).\n\n• Performance: Adequate on legacy models (GPT-3.5), but poor discrimination on modern reasoning models (GPT-4, Llama 3)."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    add_card(slide6, Inches(0.8) + (w3 + gap3)*2, Inches(1.6), w3, Inches(5.2))
    t6_3 = slide6.shapes.add_textbox(Inches(1.0) + (w3 + gap3)*2, Inches(1.8), w3 - Inches(0.4), Inches(4.8)).text_frame
    t6_3.word_wrap = True
    p = t6_3.paragraphs[0]
    p.text = "3. SAMPLE CONSISTENCY (SC)"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN
    p = t6_3.add_paragraph()
    p.text = "MultiPass: 15 Stochastic Runs"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t6_3.add_paragraph()
    p.text = "• Approach: Generate 15 stochastic responses; measure inter-response agreement.\n\n• Variant A: Sentence Embeddings (e5-small-v2 & S-PubMedBERT). Highest discrimination, but narrow range (0.8–1.0).\n\n• Variant B: GPT-4 Annotation (LLM-as-a-judge tallying agreement fraction). Achieves the best calibration!\n\n• Bottleneck: 15x computational cost."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    # ==========================================
    # SLIDE 7: RESULTS: DISCRIMINATION ANALYSIS
    # ==========================================
    slide7 = prs.slides.add_slide(blank_layout)
    add_header(slide7, "Results: Discrimination Performance (ROC AUC)")

    add_card(slide7, Inches(0.8), Inches(1.6), Inches(7.5), Inches(5.2))
    t7_1 = slide7.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(7.1), Inches(4.8)).text_frame
    t7_1.word_wrap = True
    p = t7_1.paragraphs[0]
    p.text = "Comparative Discrimination Breakdown (Diagnosis vs. Treatment)"
    p.font.size = Pt(15)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    
    p = t7_1.add_paragraph()
    p.text = "Sample Consistency (SC) dramatically outperformed SinglePass proxies across all models:\n\n" \
           "• GPT-4:\n" \
           "   - Diagnosis: SC Embedding reached ROC AUC 0.79 (95% CI: 0.75–0.83)\n" \
           "   - Treatment: SC Embedding reached ROC AUC 0.71 (95% CI: 0.67–0.75)\n" \
           "   - Token Probabilities (TLP) failed threshold (ROC AUC 0.54–0.58)\n\n" \
           "• GPT-3.5:\n" \
           "   - Diagnosis: SC Embedding reached ROC AUC 0.77 | Treatment: 0.68\n\n" \
           "• Llama 3-70B:\n" \
           "   - Diagnosis: SC reached 0.68 | Treatment Selection reached 0.75!\n\n" \
           "• Generational Divergence: Early models (GPT-3.5, Llama 2) discriminate better with TLP than CE; newer models (GPT-4, Llama 3) discriminate better with CE than TLP."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(6)

    add_card(slide7, Inches(8.6), Inches(1.6), Inches(3.9), Inches(2.45), bg_color=CARD_BG, border_color=PRIMARY_TEAL)
    t7_r1 = slide7.shapes.add_textbox(Inches(8.8), Inches(1.75), Inches(3.5), Inches(2.1)).text_frame
    t7_r1.word_wrap = True
    p = t7_r1.paragraphs[0]
    p.text = "KEY TAKEAWAY #1"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t7_r1.add_paragraph()
    p.text = "Sample Consistency Dominates"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = TEXT_DARK
    p = t7_r1.add_paragraph()
    p.text = "Measuring inter-response semantic consistency over multiple passes is the only proxy family that reliably exceeds the 0.70 clinical utility threshold."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_MUTED

    add_card(slide7, Inches(8.6), Inches(4.35), Inches(3.9), Inches(2.45), bg_color=CARD_BG, border_color=HIGHLIGHT_AMBER)
    t7_r2 = slide7.shapes.add_textbox(Inches(8.8), Inches(4.5), Inches(3.5), Inches(2.1)).text_frame
    t7_r2.word_wrap = True
    p = t7_r2.paragraphs[0]
    p.text = "KEY TAKEAWAY #2"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_AMBER
    p = t7_r2.add_paragraph()
    p.text = "The Treatment Selection Deficit"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = TEXT_DARK
    p = t7_r2.add_paragraph()
    p.text = "Uncertainty proxies consistently perform worse on treatment selection than diagnosis. In treatment, multiple semi-correct therapies exist, muddying consistency signals."
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_MUTED

    # ==========================================
    # SLIDE 8: RESULTS: CALIBRATION ANALYSIS
    # ==========================================
    slide8 = prs.slides.add_slide(blank_layout)
    add_header(slide8, "Results: Calibration Analysis & Expected Calibration Error")

    add_card(slide8, Inches(0.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t8_1 = slide8.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t8_1.word_wrap = True
    p = t8_1.paragraphs[0]
    p.text = "The Sentence Embedding Distortion"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t8_1.add_paragraph()
    p.text = "• The Paradox of Embedding Cosine Similarity:\nSentence embeddings (e5, PubMedBERT) won in discrimination (ROC AUC up to 0.79), BUT demonstrated POOR calibration.\n\n• Why? Value Clustering:\nCosine similarities between medical sentences naturally cluster between 0.80 and 1.00. This narrow dynamic range distorts calibration, yielding high Expected Calibration Error (ECE = 0.38–0.78).\n\n• Clinical Verdict: Without mathematical post-hoc re-calibration against a labeled test bank, raw embedding similarity CANNOT be used as a clinical probability."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide8, Inches(6.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t8_2 = slide8.shapes.add_textbox(Inches(7.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t8_2.word_wrap = True
    p = t8_2.paragraphs[0]
    p.text = "The Champion: SC by GPT Annotation"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN
    p = t8_2.add_paragraph()
    p.text = "• Optimal Calibration Profile:\nSample Consistency evaluated via GPT-4 annotation most closely approximated perfect calibration (matching the ideal 45° diagonal line).\n\n• Quantitative Superiority:\n   - Lowest ECE: 0.09 (GPT-4, Temp 1.0) and 0.12 (Temp 0.5)\n   - Lowest Brier Scores: 0.21–0.24 (vs. 0.38–0.50 for embeddings)\n\n• Actionable for Clinicians: If an ensemble of 15 passes yields a 9/15 agreement (60%), the observed empirical diagnostic accuracy is actually ~60%!"
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    # ==========================================
    # SLIDE 9: COMPUTATIONAL TRADE-OFFS & LIMITATIONS
    # ==========================================
    slide9 = prs.slides.add_slide(blank_layout)
    add_header(slide9, "Critical Analysis: Practicality vs. Computational Cost")

    add_card(slide9, Inches(0.8), Inches(1.6), Inches(11.733), Inches(1.5))
    t9_1 = slide9.shapes.add_textbox(Inches(1.0), Inches(1.7), Inches(11.3), Inches(1.3)).text_frame
    t9_1.word_wrap = True
    p = t9_1.paragraphs[0]
    p.text = "1. THE 15x COMPUTE PENALTY OF SAMPLE CONSISTENCY"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t9_1.add_paragraph()
    p.text = "While SC with GPT-4 annotation achieves superior calibration (ECE 0.09), it requires 15 distinct inference calls per clinical question, plus an additional judge call. In emergency medicine, ambient voice dictation, or edge mobile health (mHealth), a 15x latency penalty (>10 seconds) and 15x token cost makes naive SC completely impractical."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK

    add_card(slide9, Inches(0.8), Inches(3.3), Inches(11.733), Inches(1.5))
    t9_2 = slide9.shapes.add_textbox(Inches(1.0), Inches(3.4), Inches(11.3), Inches(1.3)).text_frame
    t9_2.word_wrap = True
    p = t9_2.paragraphs[0]
    p.text = "2. THE TREATMENT SELECTION REASONING DEFICIT"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_AMBER
    p = t9_2.add_paragraph()
    p.text = "Across nearly all models, uncertainty proxies performed significantly worse on treatment questions than diagnostic questions. In clinical pharmacotherapy, several guideline-directed therapies may be equally valid (e.g., ACE inhibitors vs ARBs), leading stochastic models to fluctuate between acceptable drugs and incorrectly registering as 'uncertain'."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK

    add_card(slide9, Inches(0.8), Inches(5.0), Inches(11.733), Inches(1.8))
    t9_3 = slide9.shapes.add_textbox(Inches(1.0), Inches(5.1), Inches(11.3), Inches(1.6)).text_frame
    t9_3.word_wrap = True
    p = t9_3.paragraphs[0]
    p.text = "3. STUDY LIMITATIONS & OPEN QUESTIONS"
    p.font.size = Pt(13)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t9_3.add_paragraph()
    p.text = "• Linguistic & Regional Bias: Limited to USMLE Step 2/3 and NEJM English-language cases; generalizability to non-English or international clinical standards (e.g., Canadian CPGs) remains unproven.\n• Zero Medical Fine-Tuning: Tested general foundation models (GPT-4, Llama 3) rather than medical-specific fine-tuned models (e.g., Med-PaLM, OpenBioLLM).\n• Call to Action: The community urgently needs single-pass calibrated decision architectures!"
    p.font.size = Pt(10.5)
    p.font.color.rgb = TEXT_DARK

    # ==========================================
    # SLIDE 10: ALIGNMENT TRIAD: RLHF, RLVR, RLCD
    # ==========================================
    slide10 = prs.slides.add_slide(blank_layout)
    add_header(slide10, "Theoretical Bridge: Solving Miscalibration via RLHF, RLVR & RLCD")

    w10 = Inches(3.7)
    gap10 = Inches(0.3)

    add_card(slide10, Inches(0.8), Inches(1.6), w10, Inches(5.2))
    t10_1 = slide10.shapes.add_textbox(Inches(1.0), Inches(1.8), w10 - Inches(0.4), Inches(4.8)).text_frame
    t10_1.word_wrap = True
    p = t10_1.paragraphs[0]
    p.text = "1. RLHF\n(Human Feedback)"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_RED
    p = t10_1.add_paragraph()
    p.text = "Why RLHF Breeds Overconfidence"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t10_1.add_paragraph()
    p.text = "• Objective: Optimizes conversational style and human rater approval.\n\n• The Failure Mode (Savage et al. confirmed): Human raters reward confident, authoritative-sounding answers. RLHF inherently bakes in conversational sycophancy and overconfidence.\n\n• Result: Confidence Elicitation (CE) fails because the model has been trained to never sound timid or uncertain!"
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide10, Inches(0.8) + w10 + gap10, Inches(1.6), w10, Inches(5.2))
    t10_2 = slide10.shapes.add_textbox(Inches(1.0) + w10 + gap10, Inches(1.8), w10 - Inches(0.4), Inches(4.8)).text_frame
    t10_2.word_wrap = True
    p = t10_2.paragraphs[0]
    p.text = "2. RLVR\n(Verifiable Rewards)"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t10_2.add_paragraph()
    p.text = "Grounding in Objective Truth"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t10_2.add_paragraph()
    p.text = "• Objective: Replaces human preference with deterministic rule checkers (e.g., EHRMIND, Lin et al., 2025; Fleming-R1).\n\n• Mechanism: Rewards models when mathematical dosage formulas (MEDCALC) or diagnostic code rules match ground truth.\n\n• Advantage: Eliminates hallucinations in billing and guideline thresholds.\n\n• Limitation: Cannot measure uncertainty in borderline patient cases."
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide10, Inches(0.8) + (w10 + gap10)*2, Inches(1.6), w10, Inches(5.2))
    t10_3 = slide10.shapes.add_textbox(Inches(1.0) + (w10 + gap10)*2, Inches(1.8), w10 - Inches(0.4), Inches(4.8)).text_frame
    t10_3.word_wrap = True
    p = t10_3.paragraphs[0]
    p.text = "3. RLCD\n(Calibrated Decisions)"
    p.font.size = Pt(14)
    p.font.bold = True
    p.font.color.rgb = HIGHLIGHT_GREEN
    p = t10_3.add_paragraph()
    p.text = "Single-Pass Calibrated Probabilities"
    p.font.size = Pt(11)
    p.font.bold = True
    p.font.color.rgb = TEXT_MUTED
    p = t10_3.add_paragraph()
    p.text = "• Objective: The missing link identified by Savage et al. (popularized by TypeSafe AI / Jev in late 2026).\n\n• Mechanism: Non-autoregressive decision layers trained via proper scoring rules (Brier score / ECE).\n\n• Clinical Triumph: Delivers perfectly calibrated decision probabilities in a SINGLE forward pass (<20ms), achieving SC accuracy with zero compute penalty!"
    p.font.size = Pt(11)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    # ==========================================
    # SLIDE 11: TRANSLATION TO OUR EHEALTH PROJECT
    # ==========================================
    slide11 = prs.slides.add_slide(blank_layout)
    add_header(slide11, "Translation to eHealth: Integration into 'e-Hospital AI-Twin'")

    add_card(slide11, Inches(0.8), Inches(1.6), Inches(11.733), Inches(5.2))
    t11 = slide11.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(11.3), Inches(4.8)).text_frame
    t11.word_wrap = True
    
    p = t11.paragraphs[0]
    p.text = "Translating Savage et al.'s JAMIA Findings into our Outpatient Architecture"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL

    p = t11.add_paragraph()
    p.text = "1. Selective RAG for Canadian Clinical Practice Guidelines (CPGs):\n" \
             "• As Savage et al. note, deploying RAG unnecessarily introduces noise. Our Risk Scorer only triggers vector retrieval of Hypertension Canada / Diabetes Canada guidelines when the patient's vitals demonstrate high uncertainty."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    p = t11.add_paragraph()
    p.text = "2. Calibrated Decision Thresholds in Asynchronous WhatsApp Triage:\n" \
             "• When patient Robert texts his home BP (138/86) and fasting glucose (6.8 mmol/L), our system applies an RLCD decision gate:\n" \
             "   - Calibrated Confidence ≥ 0.95: Automatically log FHIR Observation and update 3D Digital Twin.\n" \
             "   - Calibrated Confidence < 0.95: Escalate directly to Dr. Tremblay's priority inbox for clinician review."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    p = t11.add_paragraph()
    p.text = "3. Two-Speed Cognitive Architecture (System 1 + System 2):\n" \
             "• System 1 (Jev / Calibrated Decision Layer): Handles fast classification, triage, and billing exclusions in <20 ms.\n" \
             "• System 2 (Local Gemma 2B via Ollama): Handles complex narrative SOAP note synthesis and patient explanations."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(10)

    # ==========================================
    # SLIDE 12: SEMINAR DISCUSSION QUESTIONS & CONCLUSION
    # ==========================================
    slide12 = prs.slides.add_slide(blank_layout)
    add_header(slide12, "Conclusions & Seminar Discussion Questions")

    add_card(slide12, Inches(0.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t12_1 = slide12.shapes.add_textbox(Inches(1.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t12_1.word_wrap = True
    p = t12_1.paragraphs[0]
    p.text = "Summary of Core Contributions"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = PRIMARY_TEAL
    p = t12_1.add_paragraph()
    p.text = "1. First large-scale evaluation of LLM uncertainty on open-ended clinical questions (24,941 physician-graded answers).\n\n" \
             "2. Proved that Confidence Elicitation (asking the model) fails catastrophically due to systematic overconfidence.\n\n" \
             "3. Identified Sample Consistency by GPT-4 annotation as the premier balanced uncertainty proxy (ROC AUC 0.74, ECE 0.09).\n\n" \
             "4. Revealed the Treatment Reasoning Deficit, urging caution when using LLMs for therapy selection."
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    add_card(slide12, Inches(6.8), Inches(1.6), Inches(5.7), Inches(5.2))
    t12_2 = slide12.shapes.add_textbox(Inches(7.0), Inches(1.8), Inches(5.3), Inches(4.8)).text_frame
    t12_2.word_wrap = True
    p = t12_2.paragraphs[0]
    p.text = "Questions for Graduate Discussion"
    p.font.size = Pt(16)
    p.font.bold = True
    p.font.color.rgb = ACCENT_BLUE
    p = t12_2.add_paragraph()
    p.text = "Q1: In resource-constrained clinics or mobile health (mHealth) environments, how can we bridge the 15x latency penalty of Sample Consistency without sacrificing calibration?\n\n" \
             "Q2: Why does RLHF fundamentally handicap calibration, and should medical models completely abandon human conversational preference optimization during post-training?\n\n" \
             "Q3: How should Canadian regulatory bodies (Health Canada) define acceptable Expected Calibration Error (ECE) before certifying an AI as a Software as a Medical Device (SaMD)?"
    p.font.size = Pt(11.5)
    p.font.color.rgb = TEXT_DARK
    p.space_before = Pt(8)

    output_filename = "JAMIA_2025_Savage_LLM_Uncertainty_eHealth_Presentation.pptx"
    prs.save(output_filename)
    print(f"SUCCESS: Presentation successfully generated at: {os.path.abspath(output_filename)}")

if __name__ == "__main__":
    create_deck()
