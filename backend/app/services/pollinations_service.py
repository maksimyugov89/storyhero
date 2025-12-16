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
        # Уменьшаем таймаут до 90 секунд для более быстрой обработки ошибок
        timeout = httpx.Timeout(90.0, connect=10.0)
        async with httpx.AsyncClient(timeout=timeout) as client:
            try:
                response = await client.get(url)
            except httpx.TimeoutException as e:
                raise HTTPException(
                    status_code=504,
                    detail="Превышено время ожидания генерации изображения (90 секунд). Сервис Pollinations.ai не отвечает. Попробуйте позже."
                )
            except httpx.RequestError as e:
                raise HTTPException(
                    status_code=503,
                    detail=f"Ошибка соединения с Pollinations.ai: {str(e)}"
                )
            
            if response.status_code != 200:
                error_text = response.text[:200] if response.text else "Нет деталей ошибки"
                # Для 502 ошибки формируем более понятное сообщение
                if response.status_code == 502:
                    error_detail = f"Сервис генерации изображений временно недоступен (код 502). Попробуйте позже."
                elif response.status_code == 504:
                    error_detail = f"Сервис генерации изображений не отвечает (код 504). Попробуйте позже."
                else:
                    error_detail = f"Pollinations.ai вернул ошибку: {response.status_code} - {error_text}"
                raise HTTPException(
                    status_code=500,
                    detail=error_detail
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
            detail="Превышено время ожидания генерации изображения. Сервис Pollinations.ai не отвечает. Попробуйте позже."
        )
    except httpx.RequestError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Ошибка соединения с Pollinations.ai: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации изображения через Pollinations.ai: {str(e)}"
        )

