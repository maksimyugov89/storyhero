"""
Сервис для генерации изображений через Pollinations.ai API.
Использует Gemini для перевода промпта, затем генерирует изображение через Pollinations.ai.
Если API недоступен, генерирует простую заглушку через PIL.
"""
import logging
import httpx
from io import BytesIO
from fastapi import HTTPException
from PIL import Image, ImageDraw, ImageFont
from ..services.gemini_service import generate_text
import asyncio
import urllib.parse

logger = logging.getLogger(__name__)

# Pollinations.ai API
POLLINATIONS_API_BASE_URL = "https://image.pollinations.ai/prompt"


async def generate_raw_image(prompt: str, max_retries: int = 2, is_cover: bool = False) -> bytes:
    """
    Генерирует изображение через Pollinations.ai API.
    Для повышения качества сначала переводит промпт с русского на английский через Gemini.
    
    Args:
        prompt: Промпт на русском языке
        max_retries: Максимальное количество попыток при ошибке
        is_cover: Флаг, что это промпт для обложки (требует особой обработки)
    
    Returns:
        bytes: Байты изображения (JPEG/PNG)
    """
    import re  # Импортируем re в начале функции
    last_error = None
    for attempt in range(max_retries + 1):
        try:
            # КРИТИЧЕСКИ ВАЖНО: Для обложки используем sanitizer для полной очистки от текста
            if is_cover:
                from .prompt_sanitizer import strip_title_instructions, assert_no_text
                cleaned_prompt = strip_title_instructions(prompt)
                # Проверяем, что очистка прошла успешно
                assert_no_text(cleaned_prompt, is_cover=True)
                logger.info(f"🧼 Cover prompt sanitized (len before={len(prompt)}, len after={len(cleaned_prompt)})")
            else:
                # Для не-обложки используем простую очистку (старая логика)
                cleaned_prompt = prompt
                patterns_to_remove = [
                    r"The title '[^']+' \(in Russian Cyrillic letters\) MUST be written/drawn[^.]*\.",
                    r"The title should be[^.]*\.",
                    r"The title text should be[^.]*\.",
                    r"Style the title like[^.]*\.",
                    r"title.*MUST.*written",
                    r"title.*MUST.*drawn",
                ]
                
                for pattern in patterns_to_remove:
                    cleaned_prompt = re.sub(pattern, '', cleaned_prompt, flags=re.IGNORECASE | re.DOTALL)
                
                # Убираем двойные пробелы и точки
                cleaned_prompt = re.sub(r'\s+', ' ', cleaned_prompt)
                cleaned_prompt = re.sub(r'\.\s*\.', '.', cleaned_prompt)
                cleaned_prompt = cleaned_prompt.strip()
            
            # Проверяем, нужно ли переводить (если промпт уже на английском, пропускаем перевод)
            # Это поможет избежать добавления инструкций о тексте Gemini
            is_mostly_english = len(re.findall(r'[a-zA-Z]', cleaned_prompt)) > len(re.findall(r'[а-яА-Я]', cleaned_prompt)) * 2
            
            if is_mostly_english:
                # Промпт уже на английском - используем напрямую, без перевода через Gemini
                logger.info("📝 Промпт уже на английском, пропускаем перевод через Gemini")
                english_prompt = cleaned_prompt
            else:
                # Шаг 1: Переводим промпт с русского на английский через Gemini
                # КРИТИЧЕСКИ ВАЖНО: НЕ добавляй никаких инструкций о тексте, названии, буквах!
                translation_prompt = f"""Переведи следующий промпт для генерации изображения с русского на английский язык.
Переведи точно, сохранив все детали и стиль описания.
КРИТИЧЕСКИ ВАЖНО: НЕ добавляй никаких инструкций о тексте, названии, буквах, надписях в переводе!
Переведи ТОЛЬКО визуальное описание, без упоминаний о тексте.
НИКАКИХ упоминаний о "title", "text", "letters", "written", "drawn"!

Русский промпт: {cleaned_prompt}

Верни ТОЛЬКО английский перевод, без дополнительных объяснений или комментариев."""
                
                english_prompt = await generate_text(translation_prompt, json_mode=False)
            english_prompt = english_prompt.strip()
            
            # Если перевод не удался, используем оригинальный промпт
            if not english_prompt or len(english_prompt) < 10:
                english_prompt = prompt
            
            # ЧАСТЬ F: НЕГАТИВНЫЙ ПРОМПТ ПРОТИВ "ТРЕТЬЕЙ РУКИ" И АРТЕФАКТОВ
            # Добавляем негативные ограничения для всех изображений
            negative_prompt = (
                "extra arms, extra hands, extra fingers, deformed hands, mutated hands, "
                "bad anatomy, disfigured, extra limbs, fused fingers, missing fingers, "
                "long fingers, broken fingers, duplicate body parts, "
                "text, watermark, logo, letters, words, writing, "
                "blurry, low quality, distorted, malformed"
            )
            
            # Для обложки добавляем строгий запрет на текст и артефакты
            if is_cover:
                negative_prompt += (
                    ", title, book title, text on cover, written text, drawn text, "
                    "black bar, horizontal bar, bottom bar, frame, border, "
                    "placeholder, zeros, digits, sequences, watermark, logo, "
                    "000000000000000, artifacts, garbage text, "
                    "prompt text, style labels, age labels, character descriptions, "
                    "pixar style, years old, child character, named, "
                    "StoryHero, any text, any words, any letters, any numbers"
                )
            
            # КРИТИЧЕСКИ ВАЖНО: Удаляем все инструкции о тексте, которые Gemini мог добавить
            # Удаляем все фразы, содержащие упоминания о тексте/названии
            patterns_to_remove = [
                r"The title '[^']+' \(in Russian Cyrillic letters\) MUST be written/drawn[^.]*\.",
                r"The title should be[^.]*\.",
                r"The title text should be[^.]*\.",
                r"Style the title like[^.]*\.",
                r"title.*MUST.*written",
                r"title.*MUST.*drawn",
                r"title.*should.*large",
                r"title.*should.*bold",
                r"title.*should.*letters",
                r"title.*text.*readable",
                r"title.*artwork",
                r"comic book covers.*title",
            ]
            
            for pattern in patterns_to_remove:
                english_prompt = re.sub(pattern, '', english_prompt, flags=re.IGNORECASE | re.DOTALL)
            
            # Убираем двойные пробелы, точки и запятые
            english_prompt = re.sub(r'\s+', ' ', english_prompt)
            english_prompt = re.sub(r'\.\s*\.', '.', english_prompt)
            english_prompt = re.sub(r',\s*,', ',', english_prompt)
            english_prompt = english_prompt.strip()
            
            # Если промпт начинается с "Book cover illustration" дважды, убираем дублирование
            if english_prompt.count('Book cover illustration') > 1:
                parts = english_prompt.split('Book cover illustration')
                english_prompt = 'Book cover illustration' + ' '.join(parts[1:])
            
            # ЧАСТЬ F: Добавляем негативный промпт в конец основного промпта
            # Pollinations.ai не поддерживает отдельный параметр negative_prompt,
            # поэтому добавляем ограничения в сам промпт
            english_prompt = f"{english_prompt}. Negative: {negative_prompt}"

            # Шаг 2: Генерируем изображение через Pollinations.ai API
            # ДИАГНОСТИЧЕСКИЙ ЛОГ: проверяем, что в промпте нет упоминаний о тексте
            logger.info(
                f"🎨 Pollinations prompt (cover={is_cover}): {english_prompt[:250]}..."
            )
            
            # Финальная проверка для обложки: убеждаемся, что в URL не будет "title"
            if is_cover:
                from .prompt_sanitizer import assert_no_text
                assert_no_text(english_prompt, is_cover=True)
                # Дополнительная проверка: в URL не должно быть "title"
                if "title" in english_prompt.lower():
                    logger.error(f"❌ КРИТИЧЕСКАЯ ОШИБКА: В промпте для обложки всё ещё есть 'title'! Промпт: {english_prompt[:200]}")
                    raise HTTPException(
                        status_code=500,
                        detail="Cover prompt contains 'title' keyword - sanitization failed!"
                    )
            
            # Pollinations.ai использует простой GET запрос
            # Формат: https://image.pollinations.ai/prompt/{prompt}?width=1024&height=1024&seed=42
            # Кодируем промпт в URL (заменяем пробелы на + или используем quote)
            encoded_prompt = urllib.parse.quote(english_prompt, safe='')
            
            # Параметры для генерации изображения
            # Используем случайный seed для каждого изображения для разнообразия
            import random
            random_seed = random.randint(1, 1000000)
            params = {
                "width": 1024,
                "height": 1024,
                "seed": random_seed,  # Случайный seed для разнообразия изображений
                "model": "flux",  # Используем модель flux
                "nologo": "true",  # Без логотипа
                "enhance": "true",  # Улучшение качества
            }
            
            # Формируем URL с промптом в пути
            api_url = f"{POLLINATIONS_API_BASE_URL}/{encoded_prompt}"
            
            timeout = httpx.Timeout(300.0, connect=10.0, read=300.0)  # 5 минут таймаут
            
            async with httpx.AsyncClient(timeout=timeout, follow_redirects=True) as client:
                # Отправляем GET запрос
                logger.info(f"📤 Отправка запроса в Pollinations.ai API...")
                resp = await client.get(api_url, params=params)
                
                if resp.status_code == 503:
                    # Сервис недоступен, ждём и повторяем
                    if attempt < max_retries:
                        wait_time = 10 * (attempt + 1)  # Экспоненциальная задержка
                        logger.warning(f"⚠️ Pollinations.ai сервис недоступен, ждём {wait_time} секунд...")
                        await asyncio.sleep(wait_time)
                        continue
                    else:
                        raise HTTPException(
                            status_code=503,
                            detail="Pollinations.ai сервис недоступен. Попробуйте позже."
                        )
                
                if resp.status_code not in (200, 201, 202):
                    error_text = resp.text[:500] if resp.text else "Unknown error"
                    logger.error(f"❌ Pollinations.ai API вернул ошибку {resp.status_code}: {error_text}")
                    raise HTTPException(
                        status_code=resp.status_code,
                        detail=f"Pollinations.ai API вернул ошибку: {resp.status_code} - {error_text}"
                    )
                
                # Pollinations.ai возвращает изображение напрямую в ответе
                content_type = resp.headers.get("content-type", "")
                if "image" not in content_type:
                    logger.error(f"❌ Pollinations.ai вернул не изображение. Content-Type: {content_type}")
                    raise HTTPException(
                        status_code=500,
                        detail="Pollinations.ai вернул не изображение"
                    )
                
                image_bytes = resp.content
                
                if not image_bytes or len(image_bytes) < 100:
                    raise HTTPException(
                        status_code=500,
                        detail="Pollinations.ai вернул пустое изображение"
                    )
                
                logger.info(f"✅ Изображение успешно сгенерировано через Pollinations.ai, размер: {len(image_bytes)} байт")
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
    
    # Если все попытки исчерпаны, выбрасываем ошибку вместо fallback
    # КРИТИЧЕСКИ ВАЖНО: НЕ используем fallback для черновых изображений, чтобы не сохранять заглушки с текстом
    error_msg = f"Не удалось сгенерировать изображение через Pollinations.ai после {max_retries + 1} попыток"
    if last_error:
        error_msg += f": {last_error.detail if hasattr(last_error, 'detail') else str(last_error)}"
    logger.error(f"❌ {error_msg}")
    raise HTTPException(
        status_code=500,
        detail=error_msg
    )


def _generate_placeholder_image(prompt: str) -> bytes:
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

