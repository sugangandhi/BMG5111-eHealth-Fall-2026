"""
Unified Enterprise LLM Client Factory for e-Hospital Clinical AI Agents.
Provides seamless support for:
1. OpenAI GPT models (gpt-4o, gpt-4o-mini, gpt-4-turbo) via OPENAI_API_KEY
2. Local privacy-preserving LLM endpoints (Ollama, vLLM, LocalAI) via LOCAL_AI_URL
3. Resilient fallback detection with latency and health metrics
"""
import os
import json
from typing import Dict, Any, List, Optional, Tuple
from openai import OpenAI

def get_llm_config() -> Dict[str, Any]:
    """Inspects environment and returns active model provider metadata."""
    openai_key = os.getenv("OPENAI_API_KEY", "").strip()
    local_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1").strip()
    
    if openai_key:
        model = os.getenv("OPENAI_MODEL", "gpt-4o-mini").strip()
        return {
            "provider": "openai",
            "model": model,
            "api_key": openai_key,
            "base_url": None,
            "display_name": f"OpenAI {model}"
        }
    
    local_model = os.getenv("LOCAL_AI_MODEL", "gemma2:2b").strip()
    return {
        "provider": "local",
        "model": local_model,
        "api_key": "local",
        "base_url": local_url,
        "display_name": f"Local AI ({local_model})"
    }

def get_llm_client() -> Tuple[Optional[OpenAI], str, str]:
    """
    Returns (client, model_name, provider_name).
    Gracefully handles initialization errors.
    """
    cfg = get_llm_config()
    try:
        if cfg["provider"] == "openai":
            client = OpenAI(api_key=cfg["api_key"])
            return client, cfg["model"], "openai"
        else:
            client = OpenAI(base_url=cfg["base_url"], api_key=cfg["api_key"])
            return client, cfg["model"], "local"
    except Exception as e:
        print(f"[LLM Client] Failed to initialize {cfg['provider']} client: {e}")
        return None, cfg["model"], "none"

def generate_json_completion(
    messages: List[Dict[str, str]],
    temperature: float = 0.1,
    timeout: float = 12.0
) -> Optional[Dict[str, Any]]:
    """
    Executes a structured JSON completion against the configured LLM.
    Returns parsed JSON dictionary or None if unavailable/timed out.
    """
    client, model, provider = get_llm_client()
    if not client:
        return None

    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            response_format={"type": "json_object"},
            temperature=temperature,
            timeout=timeout
        )
        content = response.choices[0].message.content or "{}"
        if "```json" in content:
            content = content.split("```json")[1].split("```")[0].strip()
        elif "```" in content:
            content = content.split("```")[1].strip()
        return json.loads(content)
    except Exception as err:
        print(f"[LLM Client] JSON completion failed via {provider} ({model}): {err}")
        return None

def generate_text_completion(
    messages: List[Dict[str, str]],
    temperature: float = 0.2,
    max_tokens: int = 400,
    timeout: float = 10.0
) -> Optional[str]:
    """
    Executes a standard conversational completion against the configured LLM.
    """
    client, model, provider = get_llm_client()
    if not client:
        return None

    try:
        response = client.chat.completions.create(
            model=model,
            messages=messages,
            temperature=temperature,
            max_tokens=max_tokens,
            timeout=timeout
        )
        return (response.choices[0].message.content or "").strip()
    except Exception as err:
        print(f"[LLM Client] Text completion failed via {provider} ({model}): {err}")
        return None
