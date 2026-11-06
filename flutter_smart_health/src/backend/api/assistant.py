from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List
from fastapi import APIRouter

AI_CHAT_THREADS_FILE = Path(__file__).resolve().parents[3] / "backend" / "ai_chat_threads.json"

DEFAULT_AI_CHAT_SEED = [
    {
        "role": "user",
        "text": "I have a severe chest pain now",
        "isVoice": False,
        "timestamp": "10:14 AM"
    },
    {
        "role": "assistant",
        "text": "🚨 **STAT CLINICAL EMERGENCY ALERT TRANSMITTED TO INTELLIGENT DIGITAL SOLUTION**:\n\nAn immediate clinical notification and your continuous telemetry (BP: 138/88, HR: 82 BPM) have been sent directly to Intelligent Digital Solution triage desk.\n\nBecause severe chest pain can indicate an acute cardiac event, please do not delay care. Call 911 immediately or tap the WhatsApp button at the top to access direct clinical actions.",
        "isVoice": False,
        "timestamp": "10:14 AM"
    },
    {
        "role": "user",
        "text": "will you able to send message to the dr",
        "isVoice": False,
        "timestamp": "10:15 AM"
    },
    {
        "role": "assistant",
        "text": "🚨 **YES, YOUR MESSAGE HAS BEEN SENT TO INTELLIGENT DIGITAL SOLUTION**:\n\nAn urgent clinical notification along with your continuous telemetry (BP: 138/88, HR: 82 BPM) has been forwarded directly to Intelligent Digital Solution's clinical triage desk.\n\nIntelligent Digital Solution and the clinic triage team have been alerted. Tap the **WhatsApp button at the top** to view your active doctor conversation and track your response in real time.",
        "isVoice": False,
        "timestamp": "10:15 AM"
    }
]

def _load_ai_chat_threads() -> Dict[str, List[Dict[str, Any]]]:
    if AI_CHAT_THREADS_FILE.exists():
        try:
            with open(AI_CHAT_THREADS_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "1": list(DEFAULT_AI_CHAT_SEED),
        "391": list(DEFAULT_AI_CHAT_SEED)
    }

def _save_ai_chat_threads(threads: Dict[str, Any]) -> None:
    try:
        AI_CHAT_THREADS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(AI_CHAT_THREADS_FILE, "w", encoding="utf-8") as f:
            json.dump(threads, f, indent=2)
    except Exception as e:
        print(f"[AI Chat] Failed to save threads file: {e}")

from src.backend.schemas.assistant import (
    AssistantChatRequest,
    AssistantChatResponse,
    HealthAlertDecisionResponse,
    HealthAlertEventRequest,
    TrendInsightsRequest,
    TrendInsightsResponse,
    VitalsSummaryRequest,
    VitalsSummaryResponse,
)
from src.backend.schemas.stress import StressAnalysisRequest, StressAnalysisResponse
from src.backend.services.assistant_service import (
    analyze_stress,
    build_trend_insights,
    chat_with_assistant,
    summarize_vitals,
    validate_model_invocation,
)
from src.backend.services.assistant.workflows.health_alert_analysis import (
    analyze_health_alert_event,
)
from src.backend.services.patient_context_service import build_patient_context


router = APIRouter(prefix="/assistant", tags=["assistant"])


@router.get("/patients/{patient_id}/context")
async def patient_context(patient_id: str) -> dict:
    # Exposes the aggregated context for debugging and UI inspection while the
    # service layer remains responsible for joining eHospital tables.
    return await build_patient_context(patient_id)


@router.get("/history/{patient_id}")
async def get_assistant_history(patient_id: str) -> dict:
    threads = _load_ai_chat_threads()
    pid_str = str(patient_id)
    if pid_str not in threads:
        threads[pid_str] = list(DEFAULT_AI_CHAT_SEED)
        _save_ai_chat_threads(threads)
    return {"patient_id": pid_str, "messages": threads[pid_str]}


@router.post("/history/{patient_id}/clear")
async def clear_assistant_history(patient_id: str) -> dict:
    threads = _load_ai_chat_threads()
    pid_str = str(patient_id)
    threads[pid_str] = []
    _save_ai_chat_threads(threads)
    return {"patient_id": pid_str, "status": "cleared", "messages": []}


@router.post("/chat", response_model=AssistantChatResponse)
async def assistant_chat(request: AssistantChatRequest) -> AssistantChatResponse:
    # Routers keep the HTTP contract thin; prompt construction and model choice
    # live behind assistant_service for future LangGraph replacement.
    response = await chat_with_assistant(
        request.patient_id,
        request.message,
        request.history,
        request.model_invocation,
    )

    try:
        threads = _load_ai_chat_threads()
        pid_str = str(request.patient_id)
        thread = threads.setdefault(pid_str, list(DEFAULT_AI_CHAT_SEED))
        now_str = datetime.now().strftime("%I:%M %p")
        thread.append({
            "role": "user",
            "text": request.message,
            "isVoice": False,
            "timestamp": now_str
        })
        thread.append({
            "role": "assistant",
            "text": response.reply,
            "isVoice": False,
            "timestamp": now_str
        })
        _save_ai_chat_threads(threads)
    except Exception as e:
        print(f"[AI Chat History Error]: {e}")

    return response


@router.post("/vitals-summary", response_model=VitalsSummaryResponse)
async def vitals_summary(request: VitalsSummaryRequest) -> VitalsSummaryResponse:
    # The request shape is stable for Flutter charts even if the backend model
    # provider changes between Gemini, Ollama, or LangGraph later.
    summary = await summarize_vitals(request)
    return VitalsSummaryResponse(summary=summary)


@router.post("/trend-insights", response_model=TrendInsightsResponse)
async def trend_insights(request: TrendInsightsRequest) -> TrendInsightsResponse:
    # Trend insight labels are normalized by the service before crossing back to
    # Flutter, keeping chart widgets free of LLM response parsing.
    insights = await build_trend_insights(request)
    return TrendInsightsResponse(insights=insights)


@router.post("/health-alert/analyze", response_model=HealthAlertDecisionResponse)
async def health_alert_analysis(
    request: HealthAlertEventRequest,
) -> HealthAlertDecisionResponse:
    request.model_invocation = validate_model_invocation(request.model_invocation)
    return await analyze_health_alert_event(request)


@router.post("/stress-analysis", response_model=StressAnalysisResponse)
async def stress_analysis(request: StressAnalysisRequest) -> StressAnalysisResponse:
    request.model_invocation = validate_model_invocation(request.model_invocation)
    return await analyze_stress(request)
