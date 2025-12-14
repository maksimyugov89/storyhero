"""
Сервис для работы с DeepSeek API через OpenAI клиент
"""
import os
from openai import AsyncOpenAI
from fastapi import HTTPException
from typing import Optional

# Инициализация клиента DeepSeek
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY", "sk-da5dcb54fe9645c39baf71786ce9abfb")
DEEPSEEK_BASE_URL = "https://api.deepseek.com"

client = AsyncOpenAI(
    api_key=DEEPSEEK_API_KEY,
    base_url=DEEPSEEK_BASE_URL
)


async def generate_text(
    prompt: str,
    system_prompt: Optional[str] = None,
    json_mode: bool = False,
    temperature: float = 0.8,
    max_tokens: int = 4096
) -> str:
    """
    Генерирует текст через DeepSeek API.
    
    Args:
        prompt: Пользовательский промпт
        system_prompt: Системный промпт (опционально)
        json_mode: Если True, включает режим JSON (response_format)
        temperature: Температура генерации (0.0-1.0)
        max_tokens: Максимальное количество токенов
    
    Returns:
        str: Сгенерированный текст
    """
    messages = []
    
    if system_prompt:
        messages.append({"role": "system", "content": system_prompt})
    
    # Если json_mode, добавляем инструкцию в промпт
    if json_mode:
        user_prompt = f"{prompt}\n\nВерни ответ ТОЛЬКО в формате JSON, без дополнительного текста или объяснений."
    else:
        user_prompt = prompt
    
    messages.append({"role": "user", "content": user_prompt})
    
    try:
        # Формируем параметры запроса
        request_params = {
            "model": "deepseek-chat",
            "messages": messages,
            "temperature": temperature,
            "max_tokens": max_tokens
        }
        
        # Добавляем response_format для JSON режима
        if json_mode:
            request_params["response_format"] = {"type": "json_object"}
        
        # Выполняем запрос
        response = await client.chat.completions.create(**request_params)
        
        # Извлекаем контент
        if not response.choices or len(response.choices) == 0:
            raise HTTPException(
                status_code=500,
                detail="DeepSeek API вернул пустой ответ"
            )
        
        content = response.choices[0].message.content
        
        if not content or not content.strip():
            raise HTTPException(
                status_code=500,
                detail="DeepSeek API вернул пустой контент"
            )
        
        return content.strip()
        
    except HTTPException:
        raise
    except Exception as e:
        error_msg = str(e)
        # Обработка специфичных ошибок DeepSeek API
        if "402" in error_msg or "Insufficient Balance" in error_msg or "insufficient" in error_msg.lower():
            raise HTTPException(
                status_code=402,
                detail="Недостаточно средств на балансе DeepSeek API. Пожалуйста, пополните баланс API ключа."
            )
        elif "401" in error_msg or "Unauthorized" in error_msg.lower() or "invalid" in error_msg.lower() and "key" in error_msg.lower():
            raise HTTPException(
                status_code=401,
                detail="Неверный API ключ DeepSeek. Проверьте настройки DEEPSEEK_API_KEY."
            )
        else:
            raise HTTPException(
                status_code=500,
                detail=f"Ошибка при вызове DeepSeek API: {error_msg}"
            )

