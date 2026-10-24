from __future__ import annotations

from src.backend.schemas.assistant import HealthAlertDecisionResponse, HealthAlertEventRequest

async def analyze_health_alert_event(request: HealthAlertEventRequest) -> HealthAlertDecisionResponse:
    return HealthAlertDecisionResponse(
        event_id=str(request.event_source_id),
        patient_id=request.patient_id,
        severity="info",
        recommended_action="log_vital",
        clinical_rationale="Reading logged in central clinical telemetry table.",
        requires_escalation=False,
    )
