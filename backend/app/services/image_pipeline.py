"""
Сервис для генерации изображений через Pollinations.ai API.
Обеспечивает единый интерфейс для генерации черновых и финальных изображений.
Использует Pollinations.ai через pollinations_service.
"""
import logging
import os
import uuid
from fastapi import HTTPException
from typing import Optional, List

# ЗАКОММЕНТИРОВАНО - перешли на Pollinations.ai
# from .fal_service import generate_raw_image
from .pollinations_service import generate_raw_image
from .local_file_service import BASE_UPLOAD_DIR
from .storage import get_server_base_url

logger = logging.getLogger(__name__)


async def generate_draft_image(prompt: str, style: str = "storybook") -> str:
    """
    Генерирует черновое изображение через Pollinations.ai API и сохраняет его локально.
    
    Args:
        prompt: Промпт для генерации изображения (уже должен содержать стиль)
        style: Стиль изображения (используется для логирования)
    
    Returns:
        str: URL сохраненного изображения
    """
    try:
        logger.info(f"🎨 Генерация чернового изображения через Pollinations.ai для промпта: {prompt[:100]}...")
        
        # Генерируем изображение через Pollinations.ai API
        image_bytes = await generate_raw_image(prompt, max_retries=3, is_cover=False)
        
        if not image_bytes or len(image_bytes) == 0:
            raise HTTPException(
                status_code=500,
                detail="Pollinations.ai вернул пустое изображение"
            )
        
        # КРИТИЧЕСКИ ВАЖНО: Проверяем, что это действительно изображение, а не HTML или другой контент
        # Проверяем магические байты для JPEG, PNG, WebP
        is_valid_image = False
        if len(image_bytes) >= 4:
            # JPEG: FF D8 FF
            if image_bytes[:3] == b'\xff\xd8\xff':
                is_valid_image = True
            # PNG: 89 50 4E 47
            elif image_bytes[:4] == b'\x89PNG':
                is_valid_image = True
            # WebP: RIFF...WEBP
            elif image_bytes[:4] == b'RIFF' and b'WEBP' in image_bytes[:20]:
                is_valid_image = True
        
        if not is_valid_image:
            # Проверяем, не является ли это HTML (часто возвращается при ошибках)
            if b'<html' in image_bytes[:500].lower() or b'<!doctype' in image_bytes[:500].lower():
                logger.error(f"❌ Pollinations.ai вернул HTML вместо изображения. Первые 200 байт: {image_bytes[:200]}")
                raise HTTPException(
                    status_code=500,
                    detail="Pollinations.ai вернул HTML страницу вместо изображения. Попробуйте позже."
                )
            else:
                logger.error(f"❌ Полученные данные не являются валидным изображением. Первые 20 байт: {image_bytes[:20]}")
                raise HTTPException(
                    status_code=500,
                    detail="Pollinations.ai вернул невалидное изображение"
                )
        
        logger.info(f"✓ Черновое изображение сгенерировано через Pollinations.ai, размер: {len(image_bytes)} байт, формат валиден")
        
        # Сохраняем изображение локально
        drafts_dir = os.path.join(BASE_UPLOAD_DIR, "drafts")
        os.makedirs(drafts_dir, exist_ok=True)
        
        # Генерируем уникальное имя файла
        unique_filename = f"{uuid.uuid4()}.jpg"
        file_path = os.path.join(drafts_dir, unique_filename)
        
        # Сохраняем файл
        with open(file_path, "wb") as f:
            f.write(image_bytes)
        
        logger.info(f"✓ Изображение сохранено: {file_path}")
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        # Убираем порт :8000 из URL, так как через Nginx запросы идут без порта
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        public_url = f"{base_url}/static/drafts/{unique_filename}"
        logger.info(f"✓ Черновое изображение сохранено: {public_url}")
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации чернового изображения: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации чернового изображения: {str(e)}"
        )


async def generate_final_image(
    prompt: str, 
    face_url: Optional[str] = None,
    child_photo_path: Optional[str] = None,
    child_photo_paths: Optional[List[str]] = None,
    style: str = "storybook",
    book_title: Optional[str] = None,  # Название книги для обложки
    child_id: Optional[int] = None,  # ID ребёнка для использования face profile
    use_child_face: bool = True  # Использовать face profile если доступен
) -> str:
    """
    Генерирует финальное изображение через Pollinations.ai API с возможным face swap.
    
    Args:
        prompt: Промпт для генерации изображения
        face_url: URL фотографии ребёнка для face swap (опционально)
        child_photo_path: Путь к файлу фотографии ребёнка для face swap (опционально)
        child_photo_paths: Список путей к фотографиям ребёнка (опционально)
        style: Стиль изображения
    
    Returns:
        str: URL финального изображения
    """
    try:
        logger.info(f"🎨 Генерация финального изображения через Pollinations.ai для промпта: {prompt[:100]}...")
        
        # Проверяем наличие face profile и используем img2img если доступен
        face_profile_used = False
        face_verification_result = None
        
        if use_child_face and child_id:
            try:
                from ..models.child_face_profile import ChildFaceProfile
                from sqlalchemy.orm import Session
                from ..db import SessionLocal
                
                db = SessionLocal()
                try:
                    profile = db.query(ChildFaceProfile).filter(
                        ChildFaceProfile.child_id == child_id
                    ).first()
                    
                    if profile:
                        logger.info(f"✓ Найден face profile для child_id={child_id}, используем img2img с верификацией")
                        
                        # Формируем публичный URL reference изображения
                        base_url = get_server_base_url()
                        if ":8000" in base_url:
                            base_url = base_url.replace(":8000", "")
                        reference_image_url = f"{base_url}/static/{profile.reference_image_path}"
                        
                        # Определяем, является ли это обложкой
                        is_cover = "cover" in prompt.lower() and "book" in prompt.lower()
                        
                        # Улучшаем промпт для сохранения лица
                        from .pollinations_img2img_service import build_prompt, generate_with_verification
                        enhanced_prompt = build_prompt(prompt, strict_identity=True, is_cover=is_cover)
                        
                        # Генерируем с верификацией
                        strength = float(os.getenv("POLLINATIONS_STRENGTH", "0.25"))
                        max_retries = int(os.getenv("FACE_MAX_RETRIES", "3"))
                        threshold = float(os.getenv("FACE_SIMILARITY_THRESHOLD", "0.60"))
                        
                        # Для обложки получаем путь к reference.png для face swap
                        reference_image_path = None
                        if is_cover:
                            reference_image_path = os.path.join(BASE_UPLOAD_DIR, profile.reference_image_path)
                            if not os.path.exists(reference_image_path):
                                logger.warning(f"⚠️ Reference изображение не найдено: {reference_image_path}")
                                reference_image_path = None
                            else:
                                logger.info(f"✓ Reference изображение найдено для face swap обложки: {reference_image_path}")
                        
                        image_bytes, face_verification_result = await generate_with_verification(
                            prompt=enhanced_prompt,
                            reference_image_url=reference_image_url,
                            mean_embedding_bytes=profile.embedding,
                            strength=strength,
                            max_retries=max_retries,
                            similarity_threshold=threshold,
                            is_cover=is_cover,
                            reference_image_path=reference_image_path
                        )
                        
                        face_profile_used = True
                        logger.info(
                            f"✓ Face profile использован: similarity={face_verification_result.get('face_similarity', 0):.3f}, "
                            f"verified={face_verification_result.get('face_verified', False)}, "
                            f"attempts={face_verification_result.get('attempts', 0)}"
                        )
                finally:
                    db.close()
            except Exception as e:
                logger.warning(f"⚠️ Не удалось использовать face profile: {e}, используем обычную генерацию")
        
        # Определяем, является ли это обложкой (для правильной обработки промпта)
        # Проверяем промпт на наличие признаков обложки
        is_cover = "cover" in prompt.lower() and "book" in prompt.lower()
        
        # Если face profile не использован, генерируем обычным способом
        if not face_profile_used:
            # Генерируем изображение через Pollinations.ai API
            # Передаем is_cover для правильной обработки промпта
            image_bytes = await generate_raw_image(prompt, max_retries=3, is_cover=is_cover)
        
        if not image_bytes or len(image_bytes) == 0:
            raise HTTPException(
                status_code=500,
                detail="Pollinations.ai вернул пустое изображение"
            )
        
        logger.info(f"✓ Финальное изображение сгенерировано через Pollinations.ai, размер: {len(image_bytes)} байт")
        
        # Для обложки добавляем название книги программно (после генерации изображения)
        if book_title:
            try:
                from .cover_title_service import add_title_to_cover
                image_bytes = add_title_to_cover(image_bytes, book_title, style)
                logger.info(f"✓ Название книги добавлено на обложку программно: {book_title}")
            except Exception as e:
                logger.warning(f"⚠️ Не удалось добавить название на обложку: {e}")
        
        # Применяем face swap, если переданы фотографии ребёнка
        # КРИТИЧЕСКИ ВАЖНО: Используем ВСЕ фотографии для лучшего сходства!
        should_apply_face_swap = False
        photo_paths_list = []
        
        # Собираем все доступные пути к фотографиям
        if child_photo_paths:
            # Конвертируем URL в пути, если нужно
            for photo_item in child_photo_paths:
                if isinstance(photo_item, str):
                    # Если это URL, извлекаем путь
                    if "/static/" in photo_item:
                        relative_path = photo_item.split("/static/", 1)[1]
                        photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                        if os.path.exists(photo_path):
                            photo_paths_list.append(photo_path)
                            should_apply_face_swap = True
                    # Если это уже путь
                    elif os.path.exists(photo_item):
                        photo_paths_list.append(photo_item)
                        should_apply_face_swap = True
        
        # Также добавляем child_photo_path для обратной совместимости
        if child_photo_path and os.path.exists(child_photo_path):
            if child_photo_path not in photo_paths_list:
                photo_paths_list.append(child_photo_path)
            should_apply_face_swap = True
        
        if should_apply_face_swap:
            try:
                from .face_swap_service import apply_face_swap
                logger.info(f"🎭 Применение face swap с {len(photo_paths_list)} фотографиями ребёнка для идеального сходства")
                image_bytes = await apply_face_swap(
                    image_bytes, 
                    child_photo_path=child_photo_path,
                    child_photo_paths=photo_paths_list
                )
                logger.info(f"✓ Face swap применён успешно с использованием {len(photo_paths_list)} фотографий")
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при применении face swap: {str(e)}, продолжаем без face swap")
        
        # Сохраняем изображение локально
        finals_dir = os.path.join(BASE_UPLOAD_DIR, "finals")
        os.makedirs(finals_dir, exist_ok=True)
        
        # Генерируем уникальное имя файла
        unique_filename = f"{uuid.uuid4()}.jpg"
        file_path = os.path.join(finals_dir, unique_filename)
        
        # Сохраняем файл
        with open(file_path, "wb") as f:
            f.write(image_bytes)
        
        logger.info(f"✓ Изображение сохранено: {file_path}")
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        # Убираем порт :8000 из URL, так как через Nginx запросы идут без порта
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        public_url = f"{base_url}/static/finals/{unique_filename}"
        logger.info(f"✓ Финальное изображение сохранено: {public_url}")
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации финального изображения: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации финального изображения: {str(e)}"
        )

