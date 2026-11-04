import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as patches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import os

def generate_architecture_diagram():
    # 16:9 Widescreen aspect ratio (24 x 13.5 inches at 200 DPI -> 4800 x 2700 px)
    fig, ax = plt.subplots(figsize=(24, 13.5), dpi=200)
    fig.patch.set_facecolor('#0B1120') # Deep executive slate navy
    ax.set_facecolor('#0B1120')
    ax.set_xlim(0, 24)
    ax.set_ylim(0, 13.5)
    ax.axis('off')

    # Palette
    C_SLATE_BG = '#0F172A'
    C_CARD_BG = '#1E293B'
    C_INNER_BG = '#0F172A'
    C_TEAL = '#0D9488'
    C_TEAL_LIGHT = '#2DD4BF'
    C_SKY = '#0284C7'
    C_SKY_LIGHT = '#38BDF8'
    C_AMBER = '#D97706'
    C_AMBER_LIGHT = '#FBBF24'
    C_ROSE = '#E11D48'
    C_ROSE_LIGHT = '#FB7185'
    C_EMERALD = '#059669'
    C_EMERALD_LIGHT = '#34D399'
    C_TEXT_LIGHT = '#F8FAFC'
    C_TEXT_MUTED = '#94A3B8'
    C_BORDER = '#334155'

    # Title Header Block
    ax.text(0.8, 12.8, "e-HOSPITAL CLINICAL AI-TWIN", fontfamily='sans-serif', fontsize=11, fontweight='bold', color=C_TEAL_LIGHT)
    ax.text(0.8, 12.2, "Production System & Dataflow Architecture", fontfamily='serif', fontsize=22, fontweight='bold', color=C_TEXT_LIGHT)
    ax.text(0.8, 11.75, "End-to-End Outpatient Telemetry, Ambient Voice Ingestion, Dual-Speed Triage & Cloud EHR Integration", fontfamily='sans-serif', fontsize=11, color=C_TEXT_MUTED)

    # Status / Compliance Badges Top Right
    badges = [
        ("PIPEDA / HIPAA Compliant", C_EMERALD, 18.2),
        ("Hypertension Canada 2024 CPG", C_TEAL, 14.2),
        ("CTAS Acuity Levels 1-5", C_ROSE, 10.9)
    ]
    for b_text, b_col, b_x in badges:
        p = FancyBboxPatch((b_x, 12.0), 3.1, 0.45, boxstyle="round,pad=0.08,rounding_size=0.15",
                           facecolor=b_col, edgecolor='none', alpha=0.25)
        ax.add_patch(p)
        p_border = FancyBboxPatch((b_x, 12.0), 3.1, 0.45, boxstyle="round,pad=0.08,rounding_size=0.15",
                                  facecolor='none', edgecolor=b_col, linewidth=1.5)
        ax.add_patch(p_border)
        ax.text(b_x + 1.55, 12.22, b_text, ha='center', va='center', fontfamily='sans-serif', fontsize=9.5, fontweight='bold', color=C_TEXT_LIGHT)

    # -------------------------------------------------------------
    # 1. CLIENT EDGE BOUNDARY (Left Column)
    # -------------------------------------------------------------
    c_client = FancyBboxPatch((0.8, 1.2), 6.8, 9.8, boxstyle="round,pad=0.12,rounding_size=0.25",
                              facecolor=C_CARD_BG, edgecolor=C_SKY, linewidth=2.0)
    ax.add_patch(c_client)
    ax.text(1.2, 10.5, "TIER 1: CLIENT EDGE (Flutter 3.29 Mobile & Web)", fontfamily='sans-serif', fontsize=12, fontweight='bold', color=C_SKY_LIGHT)
    ax.text(1.2, 10.15, "Device Targets: iOS, Android, Desktop Chrome, Edge", fontfamily='sans-serif', fontsize=9, color=C_TEXT_MUTED)

    # Client Inner 1: WhatsApp In-App Clinic UI
    p1 = FancyBboxPatch((1.1, 7.8), 6.2, 2.1, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_BORDER, linewidth=1.2)
    ax.add_patch(p1)
    ax.text(1.3, 9.45, "WhatsApp Care Team UI (Meta Verified)", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_TEXT_LIGHT)
    ax.text(1.3, 9.05, "• Asynchronous patient-doctor conversational thread\n• Interactive CTAS Acuity & Calibrated Confidence pills\n• Real-time Doctor STAT Alert notifications\n• Expandable Clinician SOAP Triage Note card", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED, linespacing=1.35)

    # Client Inner 2: Ambient Voice Scribe (Microphone)
    p2 = FancyBboxPatch((1.1, 5.0), 6.2, 2.5, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_BORDER, linewidth=1.2)
    ax.add_patch(p2)
    ax.text(1.3, 7.15, "Ambient Voice Scribe (Web Speech API)", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_TEAL_LIGHT)
    ax.text(1.3, 6.75, "• Browser-native SpeechRecognition (Zero modal lag)\n• Interim live word streaming into text compose bar\n• Real-time user preview & edit prior to dispatch\n• 100% Edge audio processing (Zero cloud voice storage)\n• PIPEDA & HIPAA compliant voice-to-text pipeline", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED, linespacing=1.35)

    # Client Inner 3: Interactive Clinical Triggers & Chips
    p3 = FancyBboxPatch((1.1, 1.6), 6.2, 3.1, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_BORDER, linewidth=1.2)
    ax.add_patch(p3)
    ax.text(1.3, 4.35, "Clinical Action Triggers & SOCRATES Drill-down", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_AMBER_LIGHT)
    ax.text(1.3, 3.95, "• One-Tap Emergency 911 Dialing (Native tel: URI)\n• Walk-in Urgent Care Clinic Queue check-in\n• Priority appointment booking with Dr. Patel\n• Dynamic SOCRATES Chips (Pain character, onset, radiation)\n• ApiConfig Dynamic Host Resolver (PNA-aware)", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED, linespacing=1.35)

    # -------------------------------------------------------------
    # 2. CLINICAL MIDDLEWARE CORE (Middle Column)
    # -------------------------------------------------------------
    c_mid = FancyBboxPatch((8.3, 1.2), 7.6, 9.8, boxstyle="round,pad=0.12,rounding_size=0.25",
                           facecolor=C_CARD_BG, edgecolor=C_TEAL, linewidth=2.0)
    ax.add_patch(c_mid)
    ax.text(8.7, 10.5, "TIER 2: CLINICAL MIDDLEWARE (FastAPI Core :8080)", fontfamily='sans-serif', fontsize=12, fontweight='bold', color=C_TEAL_LIGHT)
    ax.text(8.7, 10.15, "Docker Container | Asynchronous Python 3.11 | Uvicorn", fontfamily='sans-serif', fontsize=9, color=C_TEXT_MUTED)

    # Mid Inner 1: Telemetry Parser & API Ingestion
    m1 = FancyBboxPatch((8.6, 8.2), 7.0, 1.7, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_BORDER, linewidth=1.2)
    ax.add_patch(m1)
    ax.text(8.8, 9.45, "REST Endpoints & Regex Vital Tokenizer", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_TEXT_LIGHT)
    ax.text(8.8, 9.05, "• POST /api/whatsapp/send | POST /api/whatsapp/action\n• Regex Vital Tokenizer: Extracts BP '150/95' & HR '82' from free text\n• Chrome Private Network Access (PNA) Preflight handler", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED, linespacing=1.35)

    # Mid Inner 2: System 1 (Deterministic Triage Engine)
    m2 = FancyBboxPatch((8.6, 4.9), 7.0, 3.0, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor='#1E1B4B', edgecolor=C_ROSE, linewidth=1.5)
    ax.add_patch(m2)
    ax.text(8.8, 7.45, "SYSTEM 1: DETERMINISTIC TRIAGE ENGINE (<20ms)", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_ROSE_LIGHT)
    ax.text(8.8, 7.05, "• Canadian Triage & Acuity Scale (CTAS Levels 1 to 5 Matrix)\n• Red-Flag Symptoms: Crushing pain, dyspnea, stroke, unconscious\n• Hypertension Canada 2024 CPG Rules:\n   - Crisis (>=180/120) -> CTAS 2 STAT Emergency Alert\n   - Stage 2 (>=140/90) + High-risk comorbidity -> CTAS 3 Urgent\n   - Stage 1 (130-139/80-89) & Target (<130/80)\n• Comorbidity Multiplier (Correlates with AFib, T2D, CAD history)\n• Zero Hallucination Guarantee on Life-Threatening Crises", fontfamily='sans-serif', fontsize=8.5, color='#E2E8F0', linespacing=1.35)

    # Mid Inner 3: System 2 (Generative Reasoning & SOAP Synthesizer)
    m3 = FancyBboxPatch((8.6, 1.6), 7.0, 3.0, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor='#064E3B', edgecolor=C_EMERALD, linewidth=1.5)
    ax.add_patch(m3)
    ax.text(8.8, 4.2, "SYSTEM 2: GENERATIVE REASONING & SOAP ENGINE", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_EMERALD_LIGHT)
    ax.text(8.8, 3.8, "• LangGraph / LangChain Agent Clinical Orchestrator\n• LLM Model Client (OpenAI GPT-4o / Local Gemma 2B fallback)\n• Calibrated Uncertainty Rating (ECE score: 0.98 high / 0.82 atypical)\n• Automated Clinician SOAP Note Generator:\n   - Subjective (Chief complaint, onset, patient phrasing)\n   - Objective (EHR comorbidity cross-reference, live telemetry)\n   - Assessment (CTAS Acuity level, CPG differential diagnosis)\n   - Plan (Emergency escalation, clinic review slot holding)", fontfamily='sans-serif', fontsize=8.5, color='#E2E8F0', linespacing=1.35)

    # -------------------------------------------------------------
    # 3. BACKEND PERSISTENCE & CLINICIAN DESK (Right Column)
    # -------------------------------------------------------------
    c_back = FancyBboxPatch((16.6, 1.2), 6.6, 9.8, boxstyle="round,pad=0.12,rounding_size=0.25",
                            facecolor=C_CARD_BG, edgecolor=C_AMBER, linewidth=2.0)
    ax.add_patch(c_back)
    ax.text(17.0, 10.5, "TIER 3 & 4: AWS CLOUD EHR & CLINICIAN DESK", fontfamily='sans-serif', fontsize=12, fontweight='bold', color=C_AMBER_LIGHT)
    ax.text(17.0, 10.15, "AWS App Runner REST | MySQL 8.0 | 72 Hospital Tables", fontfamily='sans-serif', fontsize=9, color=C_TEXT_MUTED)

    # Back Inner 1: AWS App Runner Cloud EHR
    k1 = FancyBboxPatch((16.9, 5.5), 6.0, 4.4, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_BORDER, linewidth=1.2)
    ax.add_patch(k1)
    ax.text(17.1, 9.45, "Central AWS Cloud EHR (App Runner)", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_AMBER_LIGHT)
    ax.text(17.1, 9.1, "https://aetab8pjmb.us-east-1.awsapprunner.com", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED)
    
    tables_info = [
        ("table/wearable_vitals", "Continuous HR, steps, sleep, calories, annotation"),
        ("table/vitals_history", "Ambulatory BP, resting HR, clinician review notes"),
        ("table/medical_history", "Patient active chronic comorbidities (AFib, T2D, CAD)"),
        ("table/appointments", "Instant priority booking writes (Status: Scheduled)"),
        ("table/diagnosis", "ICD-10 clinical diagnoses and attending physician ID")
    ]
    y_tbl = 8.5
    for t_name, t_desc in tables_info:
        p_tbl = FancyBboxPatch((17.1, y_tbl - 0.15), 5.6, 0.45, boxstyle="round,pad=0.05,rounding_size=0.08", facecolor='#0B1120', edgecolor='#1E293B', linewidth=1)
        ax.add_patch(p_tbl)
        ax.text(17.25, y_tbl + 0.1, t_name, fontfamily='monospace', fontsize=8, fontweight='bold', color=C_TEAL_LIGHT)
        ax.text(17.25, y_tbl - 0.05, t_desc, fontfamily='sans-serif', fontsize=7.5, color=C_TEXT_MUTED)
        y_tbl -= 0.6

    # Back Inner 2: Dr. Patel's Clinical Intake Desk
    k2 = FancyBboxPatch((16.9, 1.6), 6.0, 3.6, boxstyle="round,pad=0.1,rounding_size=0.15", facecolor=C_INNER_BG, edgecolor=C_ROSE, linewidth=1.5)
    ax.add_patch(k2)
    ax.text(17.1, 4.75, "Dr. Patel's Attending Clinician Desk", fontfamily='sans-serif', fontsize=10.5, fontweight='bold', color=C_ROSE_LIGHT)
    ax.text(17.1, 4.35, "• STAT Emergency Notice Feed (Acuity 1/2 Red Flags)\n• Formatted Clinical SOAP Notes (Direct EHR intake view)\n• Urgent Care Walk-In Queue Management & Tracking\n• Direct 911 / EMS Ambulance Integration Channel\n• Closed-loop prescription authorization queue", fontfamily='sans-serif', fontsize=8.5, color=C_TEXT_MUTED, linespacing=1.35)

    # -------------------------------------------------------------
    # CONNECTING DATAFLOW ARROWS WITH PROTOCOL BADGES
    # -------------------------------------------------------------
    # Arrow 1: Client -> FastAPI (Dispatch Message)
    arr1 = FancyArrowPatch((7.6, 8.8), (8.6, 8.8), arrowstyle='->', mutation_scale=20, linewidth=2.2, color=C_SKY_LIGHT)
    ax.add_patch(arr1)
    ax.text(8.1, 9.05, "HTTPS REST\nJSON Payload", ha='center', va='bottom', fontfamily='sans-serif', fontsize=7.5, fontweight='bold', color=C_SKY_LIGHT)

    # Arrow 2: FastAPI -> Client (Triage Response & Actions)
    arr2 = FancyArrowPatch((8.6, 8.3), (7.6, 8.3), arrowstyle='->', mutation_scale=20, linewidth=2.2, color=C_TEAL_LIGHT)
    ax.add_patch(arr2)
    ax.text(8.1, 7.85, "Triage Level,\nCTAS, Actions", ha='center', va='bottom', fontfamily='sans-serif', fontsize=7.5, fontweight='bold', color=C_TEAL_LIGHT)

    # Arrow 3: FastAPI -> AWS Cloud (Comorbidity Lookup & Telemetry Commit)
    arr3 = FancyArrowPatch((15.6, 8.8), (16.9, 8.8), arrowstyle='<->', mutation_scale=20, linewidth=2.2, color=C_AMBER_LIGHT)
    ax.add_patch(arr3)
    ax.text(16.25, 9.05, "EHR Queries &\nTelemetry Posts", ha='center', va='bottom', fontfamily='sans-serif', fontsize=7.5, fontweight='bold', color=C_AMBER_LIGHT)

    # Arrow 4: FastAPI -> Dr. Patel Desk (STAT Alerts & SOAP Notes)
    arr4 = FancyArrowPatch((15.6, 3.4), (16.9, 3.4), arrowstyle='->', mutation_scale=20, linewidth=2.2, color=C_ROSE_LIGHT)
    ax.add_patch(arr4)
    ax.text(16.25, 3.65, "STAT Alerts &\nSOAP Notes", ha='center', va='bottom', fontfamily='sans-serif', fontsize=7.5, fontweight='bold', color=C_ROSE_LIGHT)

    # Arrow 5: Client Action Click -> Appointment Commit
    arr5 = FancyArrowPatch((7.6, 2.5), (8.6, 2.5), arrowstyle='->', mutation_scale=20, linewidth=2.0, color=C_AMBER_LIGHT)
    ax.add_patch(arr5)
    ax.text(8.1, 2.7, "Action Click:\nBook Consult", ha='center', va='bottom', fontfamily='sans-serif', fontsize=7.5, fontweight='bold', color=C_AMBER_LIGHT)

    # Output paths
    png_path = "eHospital_System_Architecture_HD.png"
    svg_path = "eHospital_System_Architecture.svg"
    plt.tight_layout()
    plt.savefig(png_path, dpi=200, facecolor=fig.get_facecolor(), edgecolor='none')
    plt.savefig(svg_path, format='svg', facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close()
    print(f"Generated HD PNG: {os.path.abspath(png_path)}")
    print(f"Generated Vector SVG: {os.path.abspath(svg_path)}")

if __name__ == "__main__":
    generate_architecture_diagram()
