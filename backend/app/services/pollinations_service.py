"""
Сервис для генерации изображений через Pollinations.ai (Flux Model)
"""
import httpx
import random
from urllib.parse import quote
from fastapi import HTTPException
from ..services.deepseek_service import generate_text


async def generate_raw_image(prompt: str) -> bytes:
    """
    Генерирует изображение через Pollinations.ai.
    Сначала переводит промпт с русского на английский через DeepSeek.
    
    Args:
        prompt: Промпт на русском языке
    
    Returns:
        bytes: Байты изображения (JPEG/PNG)
    """
    try:
        # Шаг 1: Переводим промпт с русского на английский через DeepSeek
        translation_prompt = f"""Переведи следующий промпт для генерации изображения с русского на английский язык.
Переведи точно, сохранив все детали и стиль описания.

Русский промпт: {prompt}

Верни ТОЛЬКО английский перевод, без дополнительных объяснений или комментариев."""
        
        english_prompt = await generate_text(translation_prompt, json_mode=False)
        english_prompt = english_prompt.strip()
        
        # Если перевод не удался, используем оригинальный промпт
        if not english_prompt or len(english_prompt) < 10:
            english_prompt = prompt
        
        # Шаг 2: Кодируем промпт для URL
        encoded_prompt = quote(english_prompt)
        
        # Шаг 3: Формируем URL для Pollinations.ai
        seed = random.randint(0, 1000000)
        url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width=1024&height=1024&model=flux&nologo=true&seed={seed}"
        
        # Шаг 4: Скачиваем изображение
        async with httpx.AsyncClient(timeout=120.0) as client:
            response = await client.get(url)
            
            if response.status_code != 200:
                raise HTTPException(
                    status_code=500,
                    detail=f"Pollinations.ai вернул ошибку: {response.status_code} - {response.text[:200]}"
                )
            
            # Проверяем, что это изображение
            content_type = response.headers.get("content-type", "")
            if not content_type.startswith("image/"):
                raise HTTPException(
                    status_code=500,
                    detail=f"Pollinations.ai вернул не изображение: {content_type}"
                )
            
            image_bytes = response.content
            
            if not image_bytes or len(image_bytes) == 0:
                raise HTTPException(
                    status_code=500,
                    detail="Pollinations.ai вернул пустой ответ"
                )
            
            return image_bytes
            
    except HTTPException:
        raise
    except httpx.TimeoutException:
        raise HTTPException(
            status_code=504,
            detail="Timeout при генерации изображения через Pollinations.ai"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации изображения через Pollinations.ai: {str(e)}"
        )

