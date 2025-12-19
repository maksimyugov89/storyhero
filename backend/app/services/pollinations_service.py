"""
Сервис для генерации изображений через Pollinations.ai (Flux Model)
"""
import httpx
import random
import logging
from urllib.parse import quote
from fastapi import HTTPException
from ..services.deepseek_service import generate_text

logger = logging.getLogger(__name__)


async def generate_raw_image(prompt: str, max_retries: int = 2) -> bytes:
    """
    Генерирует изображение через Pollinations.ai.
    Сначала переводит промпт с русского на английский через DeepSeek.
    
    Args:
        prompt: Промпт на русском языке
        max_retries: Максимальное количество попыток при ошибке
    
    Returns:
        bytes: Байты изображения (JPEG/PNG)
    """
    last_error = None
    for attempt in range(max_retries + 1):
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
            timeout = httpx.Timeout(90.0, connect=10.0, read=90.0, write=10.0, pool=10.0)
            async with httpx.AsyncClient(timeout=timeout) as client:
                logger.info(f"🔄 Запрос к Pollinations.ai (попытка {attempt + 1}/{max_retries + 1}): {url[:100]}...")
                response = await client.get(url, timeout=timeout)
                logger.info(f"✓ Получен ответ от Pollinations.ai: статус {response.status_code}, размер {len(response.content) if response.content else 0} байт")
            
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
            
            logger.info(f"✅ Изображение успешно сгенерировано, размер: {len(image_bytes)} байт")
            return image_bytes
            
        except HTTPException as e:
            # HTTPException пробрасываем сразу (не делаем retry)
            if attempt == max_retries:
                logger.error(f"❌ Ошибка HTTP после {max_retries + 1} попыток: {e.detail}")
                raise
            logger.warning(f"⚠️ Попытка {attempt + 1}/{max_retries + 1} не удалась: {e.detail}, повторяем...")
            last_error = e
            continue
        except httpx.TimeoutException as e:
            if attempt == max_retries:
                logger.error(f"❌ Таймаут после {max_retries + 1} попыток")
                raise HTTPException(
                    status_code=504,
                    detail="Превышено время ожидания генерации изображения. Сервис Pollinations.ai не отвечает. Попробуйте позже."
                )
            logger.warning(f"⚠️ Таймаут на попытке {attempt + 1}/{max_retries + 1}, повторяем...")
            last_error = e
            continue
        except httpx.RequestError as e:
            if attempt == max_retries:
                logger.error(f"❌ Ошибка соединения после {max_retries + 1} попыток: {str(e)}")
                raise HTTPException(
                    status_code=503,
                    detail=f"Ошибка соединения с Pollinations.ai: {str(e)}"
                )
            logger.warning(f"⚠️ Ошибка соединения на попытке {attempt + 1}/{max_retries + 1}, повторяем...")
            last_error = e
            continue
        except Exception as e:
            if attempt == max_retries:
                logger.error(f"❌ Неожиданная ошибка после {max_retries + 1} попыток: {str(e)}", exc_info=True)
                raise HTTPException(
                    status_code=500,
                    detail=f"Ошибка при генерации изображения через Pollinations.ai: {str(e)}"
                )
            logger.warning(f"⚠️ Неожиданная ошибка на попытке {attempt + 1}/{max_retries + 1}: {str(e)}, повторяем...")
            last_error = e
            continue
    
    # Если все попытки исчерпаны
    if last_error:
        if isinstance(last_error, HTTPException):
            raise last_error
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации изображения через Pollinations.ai после {max_retries + 1} попыток: {str(last_error)}"
        )

