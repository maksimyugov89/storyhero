"""
Оркестратор для генерации финальных изображений с face swap
"""
import os
import httpx
from pathlib import Path
from fastapi import HTTPException
from typing import Optional, List
import logging
from .pollinations_service import generate_raw_image
from .faceswap_service import apply_face_swap, detect_face_in_image
from .local_file_service import BASE_UPLOAD_DIR, upload_image_bytes

# Максимум попыток перегенерации при отсутствии лица
MAX_FACE_RETRY_ATTEMPTS = 3

# Суффиксы для усиления промпта при перегенерации
FACE_ENHANCEMENT_SUFFIXES = [
    ", child's face clearly visible and centered, frontal view, well-lit portrait, face in sharp focus, looking at viewer",
    ", IMPORTANT: character facing camera directly, large clear face in center, portrait style, high detail face, eyes looking at viewer, soft lighting on face",
    ", CRITICAL: extreme close-up portrait of child, face fills frame, hyper-detailed facial features, studio lighting, front-facing, eye contact with viewer, no obstructions"
]

logger = logging.getLogger(__name__)


async def generate_draft_image(
    prompt: str,
    style: str = "storybook"
) -> str:
    """
    Генерирует черновое изображение без face swap (для скорости).
    
    Args:
        prompt: Промпт для генерации изображения (на русском)
        style: Стиль изображения (для будущего использования)
    
    Returns:
        str: Публичный URL сохраненного изображения
    """
    try:
        # Генерируем изображение через Pollinations.ai
        logger.info(f"Генерация чернового изображения через Pollinations.ai для промпта: {prompt[:100]}...")
        generated_image_bytes = await generate_raw_image(prompt)
        logger.info(f"✓ Черновое изображение сгенерировано, размер: {len(generated_image_bytes)} байт")
        
        # Сохраняем изображение в локальное хранилище
        import uuid
        storage_path = f"drafts/{uuid.uuid4()}.jpg"
        public_url = upload_image_bytes(generated_image_bytes, storage_path, content_type="image/jpeg")
        
        logger.info(f"✓ Черновое изображение сохранено: {public_url}")
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка в generate_draft_image: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации чернового изображения: {str(e)}"
        )


async def _generate_image_with_face_check(
    prompt: str,
    attempt: int = 0,
    needs_face: bool = True
) -> bytes:
    """
    Генерирует изображение и проверяет наличие лица.
    При отсутствии лица перегенерирует с усиленным промптом (до MAX_FACE_RETRY_ATTEMPTS раз).
    
    Args:
        prompt: Базовый промпт для генерации
        attempt: Номер текущей попытки (0-based)
        needs_face: Требуется ли проверка лица (True если будет face swap)
    
    Returns:
        bytes: Сгенерированное изображение
    """
    # Модифицируем промпт при повторных попытках
    if attempt > 0 and attempt <= len(FACE_ENHANCEMENT_SUFFIXES):
        enhanced_prompt = prompt + FACE_ENHANCEMENT_SUFFIXES[attempt - 1]
        logger.info(f"🔄 Попытка {attempt + 1}/{MAX_FACE_RETRY_ATTEMPTS}: усиленный промпт для гарантии лица")
    else:
        enhanced_prompt = prompt
    
    # Генерируем изображение
    logger.info(f"Генерация изображения через Pollinations.ai (попытка {attempt + 1})...")
    generated_image_bytes = await generate_raw_image(enhanced_prompt)
    logger.info(f"✓ Изображение сгенерировано, размер: {len(generated_image_bytes)} байт")
    
    # Если не нужна проверка лица - сразу возвращаем
    if not needs_face:
        return generated_image_bytes
    
    # Проверяем наличие лица
    face_found = detect_face_in_image(generated_image_bytes)
    
    if face_found:
        logger.info(f"✓ Лицо найдено на изображении (попытка {attempt + 1})")
        return generated_image_bytes
    
    # Лицо не найдено - пробуем перегенерировать
    if attempt < MAX_FACE_RETRY_ATTEMPTS - 1:
        logger.warning(f"⚠ Лицо не найдено, перегенерация... (попытка {attempt + 1} из {MAX_FACE_RETRY_ATTEMPTS})")
        return await _generate_image_with_face_check(prompt, attempt + 1, needs_face)
    
    # Все попытки исчерпаны
    logger.warning(f"⚠ Лицо не найдено после {MAX_FACE_RETRY_ATTEMPTS} попыток, используем последнее изображение")
    return generated_image_bytes


async def generate_final_image(
    prompt: str,
    child_photo_path: str = None,
    style: str = "storybook",
    child_photo_paths: Optional[list[str]] = None
) -> str:
    """
    Генерирует финальное изображение с возможным face swap.
    
    Процесс:
    1. Генерирует изображение через Pollinations.ai (с авто-перегенерацией при отсутствии лица)
    2. Если есть child_photo_path, применяет face swap
    3. Сохраняет результат в локальное хранилище
    
    Args:
        prompt: Промпт для генерации изображения (на русском)
        child_photo_path: Путь к фото ребёнка на диске (опционально)
        style: Стиль изображения (для будущего использования)
        child_photo_paths: Список путей к фотографиям ребёнка (опционально)
    
    Returns:
        str: Публичный URL сохраненного изображения
    """
    try:
        # Определяем, нужен ли face swap (есть ли фото ребёнка)
        photo_to_use = None
        available_photos = []
        
        if child_photo_paths:
            available_photos = [p for p in child_photo_paths if os.path.exists(p)]
            if available_photos:
                photo_to_use = available_photos[0]
        elif child_photo_path and os.path.exists(child_photo_path):
            photo_to_use = child_photo_path
            available_photos = [child_photo_path]
        
        needs_face = photo_to_use is not None
        
        # Шаг 1: Генерируем изображение с проверкой лица (если нужен face swap)
        generated_image_bytes = await _generate_image_with_face_check(
            prompt=prompt,
            attempt=0,
            needs_face=needs_face
        )
        
        # Шаг 2: Если есть фото ребёнка, применяем face swap
        if photo_to_use:
            logger.info(f"Применение face swap с фото: {photo_to_use}")
            logger.info(f"Доступно фотографий: {len(available_photos)}")
            
            # Пробуем применить face swap с разными фотографиями
            face_swap_success = False
            last_error = None
            
            for idx, photo_path in enumerate(available_photos):
                try:
                    logger.info(f"Попытка face swap с фото {idx + 1}/{len(available_photos)}: {photo_path}")
                    
                    # Читаем фото ребёнка с диска
                    with open(photo_path, 'rb') as f:
                        child_photo_bytes = f.read()
                    
                    # Применяем face swap
                    final_image_bytes = apply_face_swap(child_photo_bytes, generated_image_bytes)
                    logger.info(f"✓ Face swap применён успешно с фото {idx + 1}, размер результата: {len(final_image_bytes)} байт")
                    face_swap_success = True
                    break
                    
                except HTTPException as e:
                    last_error = e
                    # Если лицо не найдено на source фото - пробуем следующее
                    if "Лицо не найдено на source" in str(e.detail):
                        logger.warning(f"⚠ Лицо не найдено на фото {idx + 1}, пробуем следующее...")
                        continue
                    # Если лицо не найдено на target - это проблема сгенерированного изображения
                    elif "Лицо не найдено на target" in str(e.detail):
                        logger.warning(f"⚠ {e.detail}")
                        break  # Нет смысла пробовать другие фото
                    # Если face swap недоступен (503) - это КРИТИЧЕСКАЯ ошибка
                    elif e.status_code == 503:
                        error_msg = f"КРИТИЧЕСКАЯ ОШИБКА: Face swap недоступен: {e.detail}"
                        logger.error(f"❌ {error_msg}")
                        raise HTTPException(
                            status_code=500,
                            detail=error_msg + " Пожалуйста, убедитесь, что модель inswapper загружена и доступна."
                        )
                    else:
                        logger.warning(f"⚠ Ошибка face swap с фото {idx + 1}: {e.detail}")
                        continue
                except Exception as e:
                    last_error = e
                    logger.warning(f"⚠ Неожиданная ошибка face swap с фото {idx + 1}: {str(e)}")
                    continue
            
            if not face_swap_success:
                logger.warning(f"⚠ Face swap не удался ни с одним из {len(available_photos)} фото, используем оригинальное изображение")
                if last_error:
                    logger.warning(f"⚠ Последняя ошибка: {last_error}")
                final_image_bytes = generated_image_bytes
        else:
            logger.info("Фото ребёнка не указано, используем оригинальное изображение")
            final_image_bytes = generated_image_bytes
        
        # Шаг 3: Сохраняем изображение в локальное хранилище
        import uuid
        storage_path = f"final/{uuid.uuid4()}.jpg"
        public_url = upload_image_bytes(final_image_bytes, storage_path, content_type="image/jpeg")
        
        logger.info(f"✓ Изображение сохранено: {public_url}")
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка в image_pipeline: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации финального изображения: {str(e)}"
        )

