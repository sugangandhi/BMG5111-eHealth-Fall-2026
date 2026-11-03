from __future__ import annotations

import json
import requests
from typing import Any, Dict, List, Optional
from fastapi import HTTPException

from src.backend.clients.model_client import invoke_model
from src.backend.core.config import settings
from src.backend.schemas.assistant import (
    AssistantChatResponse,
    AssistantConversationMessage,
    AssistantTextResult,
    AssistantChartResult,
    AssistantChartAxis,
    AssistantChartSeries,
    AssistantChartPoint,
    ModelInvocationSettings,
)
from src.backend.services.assistant.base import AssistantProvider
from src.backend.services.patient_context_service import build_patient_context

def classify_wearable_metric_query(query: str) -> Optional[str]:
    q = query.lower()
    if any(k in q for k in ["heart", "hr", "pulse", "bpm"]):
        return "heart_rate"
    if any(k in q for k in ["step", "walk", "activity"]):
        return "steps"
    if any(k in q for k in ["sleep", "asleep", "nap"]):
        return "sleep"
    if any(k in q for k in ["calorie", "energy", "burn"]):
        return "calories"
    if any(k in q for k in ["pressure", "bp", "hypertension"]):
        return "blood_pressure"
    return None

def query_table(table_name: str, patient_id: int | str) -> List[Dict[str, Any]]:
    """Queries central eHospital App Runner database for patient data."""
    try:
        url = f"{settings.ehospital_base_url}/sql/select"
        clean_pid = str(patient_id).replace("cloud-", "").replace("pt-", "").strip()
        sql = f"SELECT * FROM {table_name} WHERE patient_id = {clean_pid} ORDER BY recorded_on DESC LIMIT 15"
        r = requests.post(url, json={"sql": sql}, timeout=6, verify=False)
        if r.status_code == 200:
            return r.json().get("data", [])
    except Exception as e:
        print(f"[QueryTable Error]: {e}")
    return []

def build_wearable_chart_graph():
    return None

def build_wearable_chart_response(metric: str, rows: List[Dict[str, Any]]) -> Optional[AssistantChartResult]:
    if not rows:
        return None
    points = []
    for idx, r in enumerate(reversed(rows[-7:])):
        val = r.get(metric)
        if val is not None:
            try:
                num = float(val)
                label = str(r.get("recorded_on", f"Day {idx+1}"))[:10]
                points.append(AssistantChartPoint(x=label, y=num, label=label))
            except Exception:
                pass
    if not points:
        return None
    return AssistantChartResult(
        displayType="line",
        title=f"{metric.replace('_', ' ').title()} Trend",
        subtitle="Recent 7 entries from eHospital telemetry",
        xAxis=AssistantChartAxis(label="Date"),
        yAxis=AssistantChartAxis(label=metric.replace('_', ' ').title()),
        series=[AssistantChartSeries(name=metric, points=points)]
    )

class WearableLangGraphAssistantProvider(AssistantProvider):
    def __init__(self, model_invocation: ModelInvocationSettings | None = None) -> None:
        self._model_invocation = model_invocation

    async def chat(
        self,
        patient_id: int | str,
        message: str,
        history: list[AssistantConversationMessage] | None = None,
    ) -> AssistantChatResponse:
        if not message.strip():
            raise HTTPException(status_code=400, detail="Message cannot be empty")

        clean_pid = str(patient_id).replace("cloud-", "").replace("pt-", "").strip()
        pid_num = int(clean_pid) if clean_pid.isdigit() else 1

        # 1. Fetch patient context and wearable vitals
        context = await build_patient_context(patient_id)
        metric = classify_wearable_metric_query(message)
        wearable_rows = query_table("wearable_vitals", pid_num)
        vitals_rows = query_table("vitals_history", pid_num)

        # Build telemetry summary string
        telemetry_lines = []
        if wearable_rows:
            latest_w = wearable_rows[0]
            telemetry_lines.append(
                f"- Wearables (Latest): HR={latest_w.get('heart_rate')} bpm, "
                f"Steps={latest_w.get('steps')}, Sleep={latest_w.get('sleep')} hrs, "
                f"Calories={latest_w.get('calories')} kcal (Recorded: {latest_w.get('recorded_on')})"
            )
        if vitals_rows:
            latest_v = vitals_rows[0]
            telemetry_lines.append(
                f"- Clinical Vitals: BP={latest_v.get('blood_pressure')}, "
                f"HR={latest_v.get('heart_rate')} bpm (Recorded: {latest_v.get('recorded_on')})"
            )
        telemetry_str = "\n".join(telemetry_lines) if telemetry_lines else "No continuous wearable data recorded."

        # 2. Build system prompt
        system_prompt = (
            "You are Smart Health AI, a clinical medical reasoning copilot for patients and attending physicians in Ontario, Canada.\n"
            "You have direct real-time access to the patient's Electronic Health Record and continuous Apple Watch/HealthKit telemetry.\n"
            f"Active Patient ID: {patient_id}\n"
            f"Clinical Telemetry Data:\n{telemetry_str}\n\n"
            "Provide empathetic, clinically accurate, evidence-based responses. "
            "Highlight vitals trends when relevant and remind the patient that they can directly message Dr. Patel on WhatsApp for acute medical needs."
        )

        history_dialogue = []
        if history:
            for h in history[-6:]:
                history_dialogue.append(f"{h.role.title()}: {h.content}")
        history_str = "\n".join(history_dialogue)
        prompt = f"Patient Inquiry: {message}"
        if history_str:
            prompt = f"Previous Conversation:\n{history_str}\n\n{prompt}"

        # 3. Invoke LLM
        reply_text = invoke_model(prompt, system_prompt=system_prompt, model_invocation=self._model_invocation)

        # 4. Build results (text + optional chart)
        results = [AssistantTextResult(content=reply_text)]
        if metric and metric in ["heart_rate", "steps", "sleep", "calories"]:
            chart = build_wearable_chart_response(metric, wearable_rows)
            if chart:
                results.append(chart)

        return AssistantChatResponse(reply=reply_text, results=results)
