import os
from fastapi import HTTPException
import requests


def call_gpt(prompt: str, system_prompt: str = None, model: str = None) -> str:
    """
    Сервис для работы с LLM через Gemini.
    Теперь вызывает Gemini API напрямую и возвращает текст.
    
    Args:
        prompt: Пользовательский промпт
        system_prompt: Системный промпт (опционально)
        model: Имя модели Gemini (если не указано, берётся из GEMINI_MODEL или дефолт)
    
    Returns:
        Ответ от Gemini API (text)
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise ValueError("GEMINI_API_KEY не установлен в переменных окружения")
    
    model_name = model or os.getenv("GEMINI_MODEL", "gemini-3-flash-preview")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_name}:generateContent"
    
    payload = {
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.8, "maxOutputTokens": 4096},
    }
    if system_prompt:
        payload["systemInstruction"] = {"parts": [{"text": system_prompt}]}
    
    try:
        resp = requests.post(url, params={"key": api_key}, json=payload, timeout=180)
    except requests.exceptions.Timeout:
        raise HTTPException(status_code=504, detail="Timeout при вызове Gemini API")
    except requests.exceptions.RequestException as e:
        raise HTTPException(status_code=503, detail=f"Ошибка соединения с Gemini API: {str(e)}")

    if resp.status_code != 200:
        try:
            err = resp.json()
            msg = err.get("error", {}).get("message") or str(err)
        except Exception:
            msg = resp.text[:400]
        raise HTTPException(status_code=resp.status_code, detail=f"Ошибка Gemini API: {msg}")

    try:
        data = resp.json()
    except Exception:
        raise HTTPException(status_code=500, detail="Gemini API вернул не-JSON ответ")

    # Извлекаем текст
    candidates = data.get("candidates") or []
    if not candidates:
        raise HTTPException(status_code=500, detail="Gemini API вернул пустой ответ (нет candidates)")
    content = (candidates[0] or {}).get("content") or {}
    parts = content.get("parts") or []
    text = "".join([p.get("text", "") for p in parts if isinstance(p, dict)]).strip()
    if not text:
        raise HTTPException(status_code=500, detail="Gemini API вернул пустой текст")
    return text

