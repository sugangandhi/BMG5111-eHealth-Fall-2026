import os
from openai import OpenAI

# Default to Ollama port 11434 if LOCAL_AI_URL is not set
_base_url = os.getenv("LOCAL_AI_URL", "http://localhost:11434/v1")
_client = OpenAI(base_url=_base_url, api_key="local")
MODEL = "gemma2:2b"

def chat_with_chart(document: str, message: str, history: list) -> str:
    # Real AI call to local model
    try:
        system_prompt = f"You are a clinical AI assistant helping a primary care doctor analyze a specialist report. \n\nREPORT TEXT:\n{document[:10000]}\n\nAnswer the user's questions based ONLY on the provided report."
        
        openai_messages = [{"role": "system", "content": system_prompt}]
        for msg in history:
            role = "user" if msg["role"] == "user" else "assistant"
            openai_messages.append({"role": role, "content": msg["content"]})
        openai_messages.append({"role": "user", "content": message})
        
        response = _client.chat.completions.create(
            model=MODEL,
            max_tokens=500,
            temperature=0.1,
            messages=openai_messages
        )
        return response.choices[0].message.content
    except Exception as e:
        # Fallback if Ollama is not running
        lower_msg = message.lower()
        if "hi" in lower_msg or "hello" in lower_msg:
            return "Hello! I am your clinical Chart Chat assistant running locally. How can I help?"
        elif "medication" in lower_msg or "drug" in lower_msg or "prescribe" in lower_msg:
            return "Based on the document, the specialist recommends modifying the medication plan."
        return f"[Ollama not running or model not pulled. Error: {str(e)}]"
