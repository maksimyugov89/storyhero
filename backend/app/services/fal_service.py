"""
Сервис для генерации изображений через fal.ai API.
ИСПОЛЬЗОВАНИЕ ЗАКОММЕНТИРОВАНО - перешли на Pollinations.ai
Использует Gemini для перевода промпта, затем генерирует изображение через fal.ai.
Если API недоступен, генерирует простую заглушку через PIL.
"""
# import logging
# import httpx
# import base64
# from io import BytesIO
# from fastapi import HTTPException
# from PIL import Image, ImageDraw, ImageFont
# from ..services.gemini_service import generate_text
# import os
# import asyncio

# logger = logging.getLogger(__name__)

# # Fal.ai API credentials
# FAL_API_KEY = os.getenv("FAL_API_KEY")
# if not FAL_API_KEY:
#     raise ValueError("FAL_API_KEY не установлен в переменных окружения. Установите его в .env файле.")
# # Используем синхронный API fal.run (более надежный)
# FAL_API_BASE_URL = "https://fal.run"
# # Используем модель flux-pro для генерации изображений
# FAL_MODEL_ID = "fal-ai/flux-pro"


# ЗАКОММЕНТИРОВАНО - используем Pollinations.ai
# async def generate_raw_image(prompt: str, max_retries: int = 2) -> bytes:
    """
    Генерирует изображение через fal.ai API (flux-pro).
    Для повышения качества сначала переводит промпт с русского на английский через Gemini.
    
    Args:
        prompt: Промпт на русском языке
        max_retries: Максимальное количество попыток при ошибке
    
    Returns:
        bytes: Байты изображения (JPEG/PNG)
    """
    last_error = None
    for attempt in range(max_retries + 1):
        try:
            # Шаг 1: Переводим промпт с русского на английский через Gemini
            translation_prompt = f"""Переведи следующий промпт для генерации изображения с русского на английский язык.
Переведи точно, сохранив все детали и стиль описания.

Русский промпт: {prompt}

Верни ТОЛЬКО английский перевод, без дополнительных объяснений или комментариев."""
            
            english_prompt = await generate_text(translation_prompt, json_mode=False)
            english_prompt = english_prompt.strip()
            
            # Если перевод не удался, используем оригинальный промпт
            if not english_prompt or len(english_prompt) < 10:
                english_prompt = prompt

            # Шаг 2: Генерируем изображение через fal.ai API
            logger.info(
                f"🔄 Запрос к fal.ai API (попытка {attempt + 1}/{max_retries + 1}): {english_prompt[:120]}..."
            )
            
            # Используем синхронный API fal.run (более простой и надежный)
            # Правильный формат: https://fal.run/{model_id}
            api_url = f"{FAL_API_BASE_URL}/{FAL_MODEL_ID}"
            
            # Payload для синхронного API
            payload = {
                    "prompt": english_prompt,
                    "image_size": "square_hd",  # 1024x1024
                    "num_inference_steps": 30,
                    "guidance_scale": 7.5,
            }
            
            timeout = httpx.Timeout(300.0, connect=10.0, read=300.0)  # 5 минут таймаут
            # Используем Bearer для авторизации (может быть Key или Bearer, пробуем оба)
            headers = {
                "Authorization": f"Key {FAL_API_KEY}",
                "Content-Type": "application/json",
            }
            
            async with httpx.AsyncClient(timeout=timeout, headers=headers, follow_redirects=True) as client:
                # Используем синхронный API - отправляем запрос и ждем результат
                logger.info(f"📤 Отправка запроса в fal.ai API...")
                resp = await client.post(api_url, json=payload)
                
                if resp.status_code == 503:
                    # Сервис недоступен, ждём и повторяем
                    if attempt < max_retries:
                        wait_time = 10 * (attempt + 1)  # Экспоненциальная задержка
                        logger.warning(f"⚠️ Fal.ai сервис недоступен, ждём {wait_time} секунд...")
                        await asyncio.sleep(wait_time)
                        continue
                    else:
                        raise HTTPException(
                            status_code=503,
                            detail="Fal.ai сервис недоступен. Попробуйте позже."
                        )
                
                if resp.status_code not in (200, 201, 202):
                    error_text = resp.text[:500] if resp.text else "Unknown error"
                    logger.error(f"❌ Fal.ai API вернул ошибку {resp.status_code}: {error_text}")
                    raise HTTPException(
                        status_code=resp.status_code,
                        detail=f"Fal.ai API вернул ошибку: {resp.status_code} - {error_text}"
                    )
                
                # Синхронный API возвращает результат напрямую
                result_data = resp.json()
                logger.info(f"📥 Получен ответ от fal.ai API")
                        
                        # Fal.ai возвращает изображение в разных форматах
                        # Проверяем output.images или images напрямую
                        output = result_data.get("output", {})
                        images = output.get("images", []) if output else result_data.get("images", [])
                        
                        image_url = images[0].get("url") if images and len(images) > 0 else None
                        image_base64 = images[0].get("content") if images and len(images) > 0 else None
                        
                        if image_url:
                            # Скачиваем изображение по URL
                    logger.info(f"📥 Скачивание изображения по URL: {image_url[:50]}...")
                            image_resp = await client.get(image_url)
                            if image_resp.status_code == 200:
                                image_bytes = image_resp.content
                            else:
                                raise HTTPException(
                                    status_code=500,
                                    detail=f"Не удалось скачать изображение: {image_resp.status_code}"
                                )
                        elif image_base64:
                            # Декодируем base64
                            if image_base64.startswith("data:image"):
                                image_base64 = image_base64.split(",", 1)[1]
                            image_bytes = base64.b64decode(image_base64)
                        else:
                    logger.error(f"❌ Fal.ai не вернул изображение. Ответ: {result_data}")
                            raise HTTPException(
                                status_code=500,
                                detail="Fal.ai не вернул изображение в ответе"
                            )
                        
                        if not image_bytes or len(image_bytes) < 100:
                            raise HTTPException(
                                status_code=500,
                                detail="Fal.ai вернул пустое изображение"
                            )
                        
                        logger.info(f"✅ Изображение успешно сгенерировано через fal.ai, размер: {len(image_bytes)} байт")
                        return image_bytes
            
        except HTTPException as e:
            # Для 503 (сервис недоступен) делаем retry
            if e.status_code == 503 and attempt < max_retries:
                wait_time = 10 * (attempt + 1)
                logger.warning(f"⚠️ Попытка {attempt + 1}/{max_retries + 1} не удалась: {e.detail}, ждём {wait_time} секунд...")
                await asyncio.sleep(wait_time)
                last_error = e
                continue
            # Для других ошибок после всех попыток - используем fallback
            elif attempt == max_retries:
                logger.warning(f"⚠️ HTTP ошибка {e.status_code} после {attempt + 1} попыток: {e.detail}. Используем fallback.")
                break
            logger.warning(f"⚠️ Попытка {attempt + 1}/{max_retries + 1} не удалась: {e.detail}, повторяем...")
            last_error = e
            continue
        except Exception as e:
            if attempt == max_retries:
                logger.warning(f"⚠️ Неожиданная ошибка после {max_retries + 1} попыток: {str(e)}. Используем fallback.")
                break
            logger.warning(f"⚠️ Неожиданная ошибка на попытке {attempt + 1}/{max_retries + 1}: {str(e)}, повторяем...")
            last_error = e
            continue
    
    # Если все попытки исчерпаны, используем fallback - генерируем простую заглушку
    logger.warning(f"⚠️ Все попытки генерации изображения через fal.ai API исчерпаны. Используем fallback - простую заглушку.")
    return _generate_placeholder_image(prompt)


# ЗАКОММЕНТИРОВАНО - используем Pollinations.ai
# def _generate_placeholder_image(prompt: str) -> bytes:
    """
    Генерирует простую заглушку изображения через PIL.
    Используется как fallback, когда внешние API недоступны.
    
    Args:
        prompt: Промпт для изображения (для отображения на заглушке)
    
    Returns:
        bytes: Байты изображения (JPEG)
    """
    try:
        # Создаём изображение 1024x1024
        width, height = 1024, 1024
        img = Image.new('RGB', (width, height), color=(240, 248, 255))  # Светло-голубой фон
        draw = ImageDraw.Draw(img)
        
        # Пробуем использовать системный шрифт
        try:
            # Пробуем разные шрифты
            font_large = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 48)
            font_small = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 32)
        except:
            try:
                font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 48)
                font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 32)
            except:
                # Используем дефолтный шрифт
                font_large = ImageFont.load_default()
                font_small = ImageFont.load_default()
        
        # Рисуем рамку
        border_color = (100, 149, 237)  # Cornflower blue
        draw.rectangle([20, 20, width-20, height-20], outline=border_color, width=10)
        
        # Рисуем заголовок
        title = "StoryHero"
        title_bbox = draw.textbbox((0, 0), title, font=font_large)
        title_width = title_bbox[2] - title_bbox[0]
        title_height = title_bbox[3] - title_bbox[1]
        draw.text(((width - title_width) // 2, 100), title, fill=(70, 130, 180), font=font_large)
        
        # Рисуем подзаголовок
        subtitle = "Изображение будет сгенерировано"
        subtitle_bbox = draw.textbbox((0, 0), subtitle, font=font_small)
        subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
        draw.text(((width - subtitle_width) // 2, 200), subtitle, fill=(105, 105, 105), font=font_small)
        
        # Обрезаем промпт для отображения (максимум 60 символов)
        display_prompt = prompt[:60] + "..." if len(prompt) > 60 else prompt
        # Разбиваем на строки по 40 символов
        words = display_prompt.split()
        lines = []
        current_line = ""
        for word in words:
            if len(current_line + " " + word) <= 40:
                current_line += (" " if current_line else "") + word
            else:
                if current_line:
                    lines.append(current_line)
                current_line = word
        if current_line:
            lines.append(current_line)
        
        # Рисуем промпт
        y_offset = 300
        for line in lines[:3]:  # Максимум 3 строки
            line_bbox = draw.textbbox((0, 0), line, font=font_small)
            line_width = line_bbox[2] - line_bbox[0]
            draw.text(((width - line_width) // 2, y_offset), line, fill=(70, 70, 70), font=font_small)
            y_offset += 50
        
        # Рисуем простую иконку (книга)
        icon_size = 200
        icon_x = (width - icon_size) // 2
        icon_y = height - 250
        # Простая книга (прямоугольник с линиями)
        draw.rectangle([icon_x, icon_y, icon_x + icon_size, icon_y + int(icon_size * 1.3)], 
                       fill=(255, 248, 220), outline=(139, 69, 19), width=3)
        # Линии страниц
        for i in range(5):
            line_y = icon_y + 20 + i * 25
            draw.line([icon_x + 10, line_y, icon_x + icon_size - 10, line_y], 
                     fill=(139, 69, 19), width=2)
        
        # Сохраняем в байты
        img_bytes = BytesIO()
        img.save(img_bytes, format='JPEG', quality=85)
        img_bytes.seek(0)
        
        logger.info(f"✅ Сгенерирована заглушка изображения, размер: {len(img_bytes.getvalue())} байт")
        return img_bytes.getvalue()
        
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации заглушки: {str(e)}", exc_info=True)
        # В крайнем случае возвращаем минимальное изображение
        img = Image.new('RGB', (1024, 1024), color=(255, 255, 255))
        img_bytes = BytesIO()
        img.save(img_bytes, format='JPEG')
        img_bytes.seek(0)
        return img_bytes.getvalue()
