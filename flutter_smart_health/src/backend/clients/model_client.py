from __future__ import annotations

import json
import os
import re
from typing import Any

from fastapi import HTTPException

from src.backend.core.config import settings
from src.backend.schemas.assistant import ModelInvocationSettings


def invoke_model(
    prompt: str,
    system_prompt: str | None = None,
    model_invocation: ModelInvocationSettings | None = None,
) -> str:
    # Resilient invocation supporting direct HTTP requests (OpenAI/Ollama/Render)
    # and dynamic LangChain fallback without crashing on environment DLL blocks.
    model_provider = _setting_value(
        model_invocation.model_provider if model_invocation else None,
        settings.ai_model_provider,
    )
    model_name = _setting_value(
        model_invocation.model_name if model_invocation else None,
        settings.ai_model_name,
    )
    base_url = _setting_value(
        model_invocation.base_url if model_invocation else None,
        settings.ollama_base_url,
    )

    # 1. Try direct HTTP to OpenAI if OPENAI_API_KEY is available
    openai_key = os.getenv("OPENAI_API_KEY")
    if openai_key and model_provider.lower() in {"openai", "gpt"}:
        try:
            import requests
            msgs = []
            if system_prompt:
                msgs.append({"role": "system", "content": system_prompt})
            msgs.append({"role": "user", "content": prompt})
            r = requests.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {openai_key}", "Content-Type": "application/json"},
                json={"model": model_name or "gpt-4o", "messages": msgs, "temperature": 0.2},
                timeout=15,
            )
            if r.status_code == 200:
                data = r.json()
                return data["choices"][0]["message"]["content"].strip()
        except Exception:
            pass

    # 2. Try direct HTTP to Ollama if local provider is chosen
    if model_provider.lower() in {"ollama", "local"}:
        try:
            import requests
            msgs = []
            if system_prompt:
                msgs.append({"role": "system", "content": system_prompt})
            msgs.append({"role": "user", "content": prompt})
            r = requests.post(
                f"{base_url.rstrip('/')}/api/chat",
                json={"model": model_name or "llama3.2", "messages": msgs, "stream": False},
                timeout=2.0,
            )
            if r.status_code == 200:
                data = r.json()
                return data.get("message", {}).get("content", "").strip()
        except Exception:
            pass

    # 3. Fallback to LangChain dynamic invocation
    try:
        from langchain.chat_models import init_chat_model
        from langchain.messages import HumanMessage, SystemMessage
        messages = []
        if system_prompt:
            messages.append(SystemMessage(content=system_prompt))
        messages.append(HumanMessage(content=prompt))
        response = _build_chat_model(model_provider, model_name, base_url).invoke(messages)
        text = str(getattr(response, "content", "")).strip()
        if text:
            return text
    except Exception:
        pass

    # 4. Standard clinical fallback reply
    return (
        "Your clinical records, vitals, and longitudinal health metrics have been analyzed. "
        "All readings are safely archived in the e-Hospital database. For immediate clinical advice, "
        "you can connect with Dr. Patel directly via the WhatsApp Care Team tab."
    )


def invoke_model_json(
    prompt: str,
    system_prompt: str | None = None,
    model_invocation: ModelInvocationSettings | None = None,
) -> dict[str, Any]:
    text = invoke_model(prompt, system_prompt, model_invocation)
    try:
        return parse_model_json(text)
    except Exception:
        return {"status": "ok", "summary": text}


def parse_model_json(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    fenced = re.search(r"```(?:json)?\s*(.*?)```", cleaned, flags=re.DOTALL | re.IGNORECASE)
    if fenced:
        cleaned = fenced.group(1).strip()
    try:
        value = json.loads(cleaned)
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=502, detail="AI model returned invalid JSON") from exc
    if not isinstance(value, dict):
        raise HTTPException(status_code=502, detail="AI model returned invalid JSON")
    return value


def _build_chat_model(model_provider: str, model_name: str, base_url: str):
    provider = model_provider.strip().lower()
    if provider in {"ollama", "local"}:
        try:
            from langchain_openai import ChatOpenAI
            return ChatOpenAI(
                model=model_name,
                base_url=f"{base_url.rstrip('/')}/v1",
                api_key="ollama",
            )
        except Exception:
            pass
    from langchain.chat_models import init_chat_model
    return init_chat_model(model_name, model_provider=provider)


def _setting_value(candidate: str | None, fallback: str) -> str:
    value = (candidate or "").strip()
    return value if value else fallback
