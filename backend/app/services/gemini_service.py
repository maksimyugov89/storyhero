"""
Сервис для работы с Google Gemini API (GenerateContent).

Ожидает переменные окружения:
- GEMINI_API_KEY: API key из Google AI Studio / Google Cloud
- GEMINI_MODEL: имя модели (по умолчанию: gemini-3-flash-preview)
"""

from __future__ import annotations

import os
import base64
import json
from typing import Optional, Any

import httpx
from fastapi import HTTPException


GEMINI_API_BASE_URL = "https://generativelanguage.googleapis.com"
DEFAULT_GEMINI_MODEL = "gemini-3-flash-preview"


def _extract_error_detail(payload: Any, fallback: str) -> str:
    try:
        if isinstance(payload, dict):
            # Типичный формат: {"error": {"message": "...", "status": "..."}}
            err = payload.get("error")
            if isinstance(err, dict):
                msg = err.get("message")
                if msg:
                    return str(msg)
            # Иногда API возвращает иные поля
            msg = payload.get("message") or payload.get("detail")
            if msg:
                return str(msg)
    except Exception:
        pass
    return fallback


def _extract_text_from_response(payload: Any) -> str:
    """
    Gemini generateContent возвращает candidates[].content.parts[].text.
    """
    import logging
    logger = logging.getLogger(__name__)
    
    if not isinstance(payload, dict):
        raise ValueError("Gemini API вернул некорректный JSON (не объект)")

    candidates = payload.get("candidates") or []
    if not candidates:
        # Проверяем наличие safety блокировок
        prompt_feedback = payload.get("promptFeedback")
        if prompt_feedback:
            block_reason = prompt_feedback.get("blockReason")
            safety_ratings = prompt_feedback.get("safetyRatings", [])
            if block_reason:
                reasons = [sr.get("category") for sr in safety_ratings if sr.get("probability") in ("HIGH", "MEDIUM")]
                raise ValueError(f"Gemini API заблокировал запрос (blockReason={block_reason}, safetyRatings={reasons})")
        raise ValueError("Gemini API вернул пустой ответ (нет candidates)")

    first = candidates[0] if isinstance(candidates, list) else None
    if not isinstance(first, dict):
        raise ValueError("Gemini API вернул некорректный candidate")

    # Проверяем finishReason (может быть SAFETY, RECITATION, etc.)
    finish_reason = first.get("finishReason")
    if finish_reason and finish_reason != "STOP":
        safety_ratings = first.get("safetyRatings", [])
        blocked_categories = [sr.get("category") for sr in safety_ratings if sr.get("probability") in ("HIGH", "MEDIUM")]
        logger.warning(f"⚠️ Gemini finishReason={finish_reason}, safetyRatings={blocked_categories}")
        if finish_reason in ("SAFETY", "RECITATION", "OTHER"):
            raise ValueError(f"Gemini API заблокировал ответ (finishReason={finish_reason}, categories={blocked_categories})")

    content = first.get("content")
    if not isinstance(content, dict):
        logger.error(f"❌ Gemini response structure: candidates[0]={first}")
        raise ValueError("Gemini API вернул некорректный content")

    parts = content.get("parts") or []
    if not isinstance(parts, list) or not parts:
        # Логируем полный ответ для диагностики
        import json as json_module
        logger.error(f"❌ Gemini вернул пустой parts. Полный ответ: {json_module.dumps(payload, indent=2, ensure_ascii=False)[:2000]}")
        logger.error(f"❌ candidate[0] structure: {json_module.dumps(first, indent=2, ensure_ascii=False)[:1000]}")
        logger.error(f"❌ content structure: {json_module.dumps(content, indent=2, ensure_ascii=False)[:1000]}")
        
        # Проверяем finishReason и safetyRatings
        finish_reason = first.get("finishReason")
        safety_ratings = first.get("safetyRatings", [])
        if finish_reason:
            logger.error(f"❌ finishReason: {finish_reason}, safetyRatings: {json_module.dumps(safety_ratings, indent=2, ensure_ascii=False)[:500]}")
        
        raise ValueError("Gemini API вернул пустой content.parts")

    texts: list[str] = []
    for part in parts:
        if isinstance(part, dict) and isinstance(part.get("text"), str):
            texts.append(part["text"])

    text = "".join(texts).strip()
    if not text:
        logger.warning(f"⚠️ Gemini вернул пустой текст после извлечения. parts={parts}")
        raise ValueError("Gemini API вернул пустой текст")

    return text


def _extract_first_inline_image_from_response(payload: Any) -> tuple[str, bytes]:
    """
    Пытается извлечь изображение из ответа Gemini.

    Ожидаемый формат (может отличаться в зависимости от версии API/модели):
      candidates[].content.parts[].inlineData = { mimeType: "...", data: "<base64>" }
    """
    if not isinstance(payload, dict):
        raise ValueError("Gemini API вернул некорректный JSON (не объект)")

    candidates = payload.get("candidates") or []
    if not isinstance(candidates, list) or not candidates:
        raise ValueError("Gemini API вернул пустой ответ (нет candidates)")

    for cand in candidates:
        if not isinstance(cand, dict):
            continue
        content = cand.get("content")
        if not isinstance(content, dict):
            continue
        parts = content.get("parts") or []
        if not isinstance(parts, list):
            continue
        for part in parts:
            if not isinstance(part, dict):
                continue
            inline = part.get("inlineData") or part.get("inline_data")
            if not isinstance(inline, dict):
                continue
            mime = inline.get("mimeType") or inline.get("mime_type") or "application/octet-stream"
            data = inline.get("data")
            if not isinstance(data, str) or not data.strip():
                continue
            try:
                raw = base64.b64decode(data, validate=False)
            except Exception as e:
                raise ValueError(f"Не удалось декодировать base64 изображения: {str(e)}")
            if not raw:
                raise ValueError("Gemini вернул пустые байты изображения")
            return str(mime), raw

    raise ValueError("Gemini API не вернул изображение (нет inlineData)")


async def generate_text(
    prompt: str,
    system_prompt: Optional[str] = None,
    json_mode: bool = False,
    temperature: float = 0.8,
    max_tokens: int = 4096,
) -> str:
    """
    Генерирует текст через Gemini API.

    Args:
        prompt: пользовательский промпт
        system_prompt: системная инструкция (опционально)
        json_mode: если True, просим вернуть строго JSON
        temperature: температура генерации
        max_tokens: максимум токенов ответа (maxOutputTokens)
    """
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(
            status_code=500,
            detail="GEMINI_API_KEY не установлен в переменных окружения",
        )

    model = os.getenv("GEMINI_MODEL", DEFAULT_GEMINI_MODEL).strip() or DEFAULT_GEMINI_MODEL

    # В json_mode дополнительно ужесточаем инструкцию, даже если caller уже добавляет требования
    user_prompt = (
        f"{prompt}\n\nВерни ответ ТОЛЬКО в формате JSON, без дополнительного текста или объяснений."
        if json_mode
        else prompt
    )

    url = f"{GEMINI_API_BASE_URL}/v1beta/models/{model}:generateContent"
    params = {"key": api_key}

    payload: dict[str, Any] = {
        "contents": [
            {
                "role": "user",
                "parts": [{"text": user_prompt}],
            }
        ],
        "generationConfig": {
            "temperature": float(temperature),
            "maxOutputTokens": int(max_tokens),
        },
    }

    # Официальный способ передать "system prompt" в Gemini API
    if system_prompt:
        payload["systemInstruction"] = {"parts": [{"text": system_prompt}]}

    # Если API/версия поддерживает responseMimeType, это повышает шанс получить чистый JSON
    if json_mode:
        payload["generationConfig"]["responseMimeType"] = "application/json"

    timeout = httpx.Timeout(180.0, connect=10.0, read=180.0, write=10.0, pool=10.0)
    async with httpx.AsyncClient(timeout=timeout) as client:
        try:
            resp = await client.post(url, params=params, json=payload)
        except httpx.TimeoutException:
            raise HTTPException(status_code=504, detail="Таймаут при вызове Gemini API")
        except httpx.RequestError as e:
            raise HTTPException(status_code=503, detail=f"Ошибка соединения с Gemini API: {str(e)}")

    # Ошибки API
    if resp.status_code != 200:
        try:
            err_json = resp.json()
            detail = _extract_error_detail(err_json, resp.text[:400])
        except Exception:
            detail = (resp.text or "").strip()[:400] or "Неизвестная ошибка Gemini API"

        # Пробуем маппить наиболее частые коды
        if resp.status_code in (401, 403):
            raise HTTPException(status_code=resp.status_code, detail="Доступ к Gemini API запрещён: проверьте GEMINI_API_KEY/проект")
        if resp.status_code == 429:
            raise HTTPException(status_code=429, detail=f"Лимит запросов Gemini API: {detail}")
        raise HTTPException(status_code=resp.status_code, detail=f"Ошибка Gemini API: {detail}")

    # Успешный ответ
    try:
        data = resp.json()
    except Exception:
        raise HTTPException(status_code=500, detail="Gemini API вернул не-JSON ответ")

    # Логируем полный ответ для диагностики (если нет candidates)
    if not data.get("candidates"):
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"❌ Gemini API вернул ответ без candidates. Полный ответ: {json.dumps(data, indent=2, ensure_ascii=False)[:2000]}")
        
        # Проверяем promptFeedback на блокировки
        prompt_feedback = data.get("promptFeedback")
        if prompt_feedback:
            block_reason = prompt_feedback.get("blockReason")
            safety_ratings = prompt_feedback.get("safetyRatings", [])
            if block_reason:
                reasons = [f"{sr.get('category')}:{sr.get('probability')}" for sr in safety_ratings]
                raise HTTPException(
                    status_code=400,
                    detail=f"Gemini API заблокировал запрос (blockReason={block_reason}, safetyRatings={reasons}). Попробуйте упростить промпт."
                )

    try:
        return _extract_text_from_response(data)
    except Exception as e:
        import logging
        logger = logging.getLogger(__name__)
        logger.error(f"❌ Ошибка извлечения текста из ответа Gemini. Ответ: {json.dumps(data, indent=2, ensure_ascii=False)[:2000]}")
        raise HTTPException(status_code=500, detail=f"Gemini API вернул некорректный ответ: {str(e)}")


async def generate_image_bytes(
    prompt: str,
    system_prompt: Optional[str] = None,
    temperature: float = 0.6,
    max_tokens: int = 2048,
) -> bytes:
    """
    Генерирует изображение через Gemini API.

    ВНИМАНИЕ: Gemini 3 Flash не поддерживает генерацию изображений.
    Эта функция всегда будет возвращать ошибку.
    Используйте другой сервис для генерации изображений (например, fal.ai через fal_service).
    """
    raise HTTPException(
        status_code=501,
        detail="Gemini 3 Flash не поддерживает генерацию изображений. Используйте pollinations_service.generate_raw_image() для генерации изображений."
    )


