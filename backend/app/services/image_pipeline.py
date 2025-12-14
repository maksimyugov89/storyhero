"""
Оркестратор для генерации финальных изображений с face swap
"""
import os
import httpx
from pathlib import Path
from fastapi import HTTPException
import logging
from .pollinations_service import generate_raw_image
from .faceswap_service import apply_face_swap
from .local_file_service import BASE_UPLOAD_DIR, upload_image_bytes

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


async def generate_final_image(
    prompt: str,
    child_photo_path: str = None,
    style: str = "storybook"
) -> str:
    """
    Генерирует финальное изображение с возможным face swap.
    
    Процесс:
    1. Генерирует изображение через Pollinations.ai
    2. Если есть child_photo_path, применяет face swap
    3. Сохраняет результат в локальное хранилище
    
    Args:
        prompt: Промпт для генерации изображения (на русском)
        child_photo_path: Путь к фото ребёнка на диске (опционально)
        style: Стиль изображения (для будущего использования)
    
    Returns:
        str: Публичный URL сохраненного изображения
    """
    try:
        # Шаг 1: Генерируем изображение через Pollinations.ai
        logger.info(f"Генерация изображения через Pollinations.ai для промпта: {prompt[:100]}...")
        generated_image_bytes = await generate_raw_image(prompt)
        logger.info(f"✓ Изображение сгенерировано, размер: {len(generated_image_bytes)} байт")
        
        # Шаг 2: Если есть фото ребёнка, применяем face swap
        if child_photo_path and os.path.exists(child_photo_path):
            try:
                logger.info(f"Применение face swap с фото: {child_photo_path}")
                
                # Читаем фото ребёнка с диска
                with open(child_photo_path, 'rb') as f:
                    child_photo_bytes = f.read()
                
                # Применяем face swap
                final_image_bytes = apply_face_swap(child_photo_bytes, generated_image_bytes)
                logger.info(f"✓ Face swap применён, размер результата: {len(final_image_bytes)} байт")
                
            except Exception as e:
                logger.warning(f"⚠ Ошибка при применении face swap: {str(e)}, используем оригинальное изображение")
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

