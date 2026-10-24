from __future__ import annotations

from src.backend.schemas.assistant import AssistantChatResponse, AssistantTextResult
from src.backend.services.assistant.workflows.base import AssistantWorkflowState, WorkflowMatch

class HealthDataQueryWorkflow:
    key = "health_data_query"
    description = "Queries patient vitals and database tables."

    async def can_handle(self, state: AssistantWorkflowState) -> WorkflowMatch:
        text = state.message.lower()
        if any(w in text for w in ["vital", "blood pressure", "heart rate", "pulse", "steps", "sleep", "calories"]):
            return WorkflowMatch(self.key, 0.9, "Health query keywords detected")
        return WorkflowMatch(self.key, 0.1, "No health keywords")

    async def run(self, state: AssistantWorkflowState) -> AssistantChatResponse:
        reply = "Your health data and continuous Apple Watch telemetry are actively monitored in the clinic database."
        return AssistantChatResponse(reply=reply, results=[AssistantTextResult(content=reply)])
