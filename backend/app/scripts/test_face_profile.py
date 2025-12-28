"""
Smoke test для face profile функциональности.
Проверяет создание face profile и генерацию с верификацией.
"""
import sys
import os
sys.path.insert(0, '/app')

import asyncio
from app.db import SessionLocal
from app.models import Child, ChildFaceProfile
from app.services.face_service import build_face_profile
from app.services.pollinations_img2img_service import generate_with_verification
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


async def test_face_profile():
    """Тест создания face profile."""
    db = SessionLocal()
    try:
        # Находим первого ребёнка в БД
        child = db.query(Child).first()
        if not child:
            logger.error("❌ Не найден ни один ребёнок в БД")
            return
        
        logger.info(f"📸 Тестирование face profile для child_id={child.id}, name={child.name}")
        
        # Получаем фотографии ребёнка
        from app.routers.children import _get_child_photos_urls
        photo_urls = _get_child_photos_urls(child.id)
        
        if len(photo_urls) < 3:
            logger.error(f"❌ Недостаточно фотографий: {len(photo_urls)}, требуется минимум 3")
            return
        
        logger.info(f"✓ Найдено {len(photo_urls)} фотографий")
        
        # Создаём face profile
        try:
            profile_data = build_face_profile(photo_urls[:5], child.id)  # Используем до 5 фото
            logger.info(f"✅ Face profile создан:")
            logger.info(f"   - Valid faces: {profile_data['valid_faces']}")
            logger.info(f"   - Used faces: {profile_data['used_faces']}")
            logger.info(f"   - Reference URL: {profile_data['reference_public_url']}")
            
            # Проверяем, что файл reference.png существует
            from app.services.storage import BASE_UPLOAD_DIR
            reference_path = os.path.join(BASE_UPLOAD_DIR, profile_data['reference_rel_path'])
            if os.path.exists(reference_path):
                logger.info(f"✓ Reference изображение существует: {reference_path}")
            else:
                logger.error(f"❌ Reference изображение не найдено: {reference_path}")
            
            # Проверяем запись в БД
            profile = db.query(ChildFaceProfile).filter(
                ChildFaceProfile.child_id == child.id
            ).first()
            
            if profile:
                logger.info(f"✓ Face profile сохранён в БД: id={profile.id}")
            else:
                logger.warning("⚠️ Face profile не найден в БД (возможно, нужно создать через API)")
            
        except Exception as e:
            logger.error(f"❌ Ошибка при создании face profile: {e}", exc_info=True)
            return
        
        # Тест генерации с верификацией (опционально, если есть reference)
        if profile:
            logger.info("🔄 Тест генерации с верификацией...")
            try:
                test_prompt = "A 5-year-old child playing in a garden, watercolor style"
                
                # Формируем публичный URL
                from app.services.storage import get_server_base_url
                base_url = get_server_base_url()
                if ":8000" in base_url:
                    base_url = base_url.replace(":8000", "")
                reference_public_url = f"{base_url}/static/{profile.reference_image_path}"
                
                # Генерируем с верификацией (1 попытка для теста)
                result_bytes, verification_result = await generate_with_verification(
                    prompt=test_prompt,
                    reference_image_url=reference_public_url,
                    mean_embedding_bytes=profile.embedding,
                    strength=0.25,
                    max_retries=1,  # Только 1 попытка для теста
                    similarity_threshold=0.60
                )
                
                logger.info(f"✅ Генерация с верификацией завершена:")
                logger.info(f"   - Similarity: {verification_result.get('face_similarity', 0):.3f}")
                logger.info(f"   - Verified: {verification_result.get('face_verified', False)}")
                logger.info(f"   - Attempts: {verification_result.get('attempts', 0)}")
                logger.info(f"   - Image size: {len(result_bytes)} bytes")
                
            except Exception as e:
                logger.warning(f"⚠️ Ошибка при тесте генерации: {e}")
                logger.warning("   (Это нормально, если Pollinations.ai недоступен или нет интернета)")
        
        logger.info("✅ Тест завершён")
        
    except Exception as e:
        logger.error(f"❌ Ошибка в тесте: {e}", exc_info=True)
    finally:
        db.close()


if __name__ == "__main__":
    asyncio.run(test_face_profile())

