import os
import requests
from fastapi import HTTPException


def call_gpt(prompt: str, system_prompt: str = None, model: str = "google/gemini-2.0-flash-001") -> str:
    """
    Вызывает OpenRouter API и возвращает ответ.
    Использует fallback механику: при ошибке 5xx или наличии "error" в JSON
    автоматически переключается на резервную модель.
    
    Args:
        prompt: Пользовательский промпт
        system_prompt: Системный промпт (опционально)
        model: Модель для использования (по умолчанию google/gemini-2.0-flash-001)
    
    Returns:
        Ответ от OpenRouter API
    """
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        raise ValueError("OPENROUTER_API_KEY не установлен в переменных окружения")
    
    url = "https://openrouter.ai/api/v1/chat/completions"
    
    messages = []
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    messages.append({"role": "user", "content": prompt})
    
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "HTTP-Referer": "http://storyhero.app",
        "X-Title": "StoryHero"
    }
    
    # Функция для выполнения запроса
    def make_request(model_name: str):
        payload = {
            "model": model_name,
            "messages": messages,
            "temperature": 0.8,
            "max_tokens": 4096
        }
        
        response = requests.post(url, headers=headers, json=payload, timeout=180)
        
        # Проверяем статус код
        if response.status_code >= 500:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Ошибка OpenRouter API (5xx): {response.text}"
            )
        
        # Парсим JSON ответ
        try:
            result = response.json()
        except ValueError as e:
            # Если ответ пустой или не JSON
            response_text = response.text if hasattr(response, 'text') else str(response.content)
            if not response_text or not response_text.strip():
                raise HTTPException(
                    status_code=500,
                    detail="Fallback модель вернула пустой ответ"
                )
            raise HTTPException(
                status_code=500,
                detail=f"Не удалось распарсить JSON ответ: {response_text[:200]}"
            )
        except Exception as e:
            response_text = response.text if hasattr(response, 'text') else str(response.content)
            raise HTTPException(
                status_code=500,
                detail=f"Ошибка при парсинге ответа API: {str(e)}. Ответ: {response_text[:200]}"
            )
        
        # Проверяем наличие ошибки в JSON
        if "error" in result:
            error_detail = result.get("error", {}).get("message", str(result.get("error")))
            raise HTTPException(
                status_code=response.status_code if response.status_code != 200 else 500,
                detail=f"Ошибка в ответе API: {error_detail}"
            )
        
        # Проверяем наличие choices
        if "choices" not in result or not result["choices"]:
            raise HTTPException(
                status_code=500,
                detail="Ответ API не содержит choices"
            )
        
        # Получаем контент ответа
        content = result["choices"][0]["message"]["content"]
        
        # Проверяем, что контент не пустой
        if not content or not content.strip():
            raise HTTPException(
                status_code=500,
                detail="Ответ API пустой"
            )
        
        return content
    
    # Пытаемся использовать основную модель
    try:
        return make_request(model)
    except HTTPException as e:
        # Если ошибка 5xx или есть error в JSON, пробуем fallback
        fallback_model = "google/gemini-2.0-flash-lite-preview-02-05"
        
        try:
            return make_request(fallback_model)
        except HTTPException as fallback_error:
            # Если fallback тоже упал, кидаем общую ошибку
            raise HTTPException(
                status_code=500,
                detail=f"LLM failed (primary + fallback). Primary error: {str(e.detail)}, Fallback error: {str(fallback_error.detail)}"
            )
    except requests.exceptions.RequestException as e:
        # Если сетевой запрос упал, пробуем fallback
        fallback_model = "google/gemini-2.0-flash-lite-preview-02-05"
        
        try:
            return make_request(fallback_model)
        except Exception as fallback_error:
            raise HTTPException(
                status_code=500,
                detail=f"LLM failed (primary + fallback). Primary error: {str(e)}, Fallback error: {str(fallback_error)}"
            )

