from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
import requests

from ..db import get_db
from ..models import Scene, Image, ThemeStyle, Book
from ..services.image_pipeline import generate_draft_image
from ..services.local_file_service import upload_image_bytes
from ..core.deps import get_current_user

router = APIRouter(tags=["images"])


class ImageRequest(BaseModel):
    book_id: str  # UUID как строка
    face_url: str  # фото ребёнка


async def _generate_draft_images_internal(
    data: ImageRequest,
    db: Session,
    user_id: str,
    final_style: str = None
):
    """
    Внутренняя функция для генерации черновых изображений.
    Принимает user_id напрямую, без Depends().
    """
    import logging
    logger = logging.getLogger(__name__)
    
    # Преобразуем строку book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(data.book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    logger.info(f"🖼️ _generate_draft_images_internal: Начало для book_id={data.book_id}")
    
    # Проверяем, что книга принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    if not book:
        raise HTTPException(status_code=403, detail="Доступ запрещен: книга не принадлежит вам")
    
    scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()

    if not scenes:
        raise HTTPException(status_code=404, detail="Scenes not found")

    logger.info(f"🖼️ _generate_draft_images_internal: Найдено сцен: {len(scenes)}")

    # Получаем final_style из параметра или из ThemeStyle (если не передан)
    if not final_style:
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        final_style = theme_style.final_style if theme_style else "storybook"
    logger.info(f"🖼️ _generate_draft_images_internal: Стиль: {final_style}")

    results = []
    scenes_with_prompts = [s for s in scenes if s.image_prompt]
    logger.info(f"🖼️ _generate_draft_images_internal: Сцен с промптами: {len(scenes_with_prompts)}")

    for idx, scene in enumerate(scenes_with_prompts, 1):
        logger.info(f"🖼️ Генерация изображения {idx}/{len(scenes_with_prompts)} для сцены order={scene.order}")
        
        # Формируем промпт с финальным стилем (если есть)
        if final_style:
            enhanced_prompt = f"Visual style: {final_style}. {scene.image_prompt}"
        else:
            enhanced_prompt = scene.image_prompt
            final_style = "storybook"  # дефолтный стиль
        
        # Генерируем черновое изображение через image_pipeline
        try:
            logger.info(f"🖼️ Вызов generate_draft_image для сцены order={scene.order}")
            image_url = await generate_draft_image(enhanced_prompt, style=final_style)
            logger.info(f"✓ Изображение сгенерировано для сцены order={scene.order}: {image_url}")
        except HTTPException as e:
            # HTTPException имеет атрибут detail, извлекаем его
            error_message = f"Ошибка при генерации изображения для сцены order={scene.order}: {e.status_code}: {e.detail}"
            logger.error(f"❌ {error_message}", exc_info=True)
            raise
        except Exception as e:
            error_message = f"Ошибка при генерации изображения для сцены order={scene.order}: {str(e)}"
            logger.error(f"❌ {error_message}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=error_message
            )
        
        # Сохраняем или обновляем запись в БД
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == scene.order
        ).first()
        
        if image_record:
            image_record.draft_url = image_url
        else:
            image_record = Image(
                book_id=book_uuid,
                scene_order=scene.order,
                draft_url=image_url
            )
            db.add(image_record)
        
        results.append({"order": scene.order, "image_url": image_url})
        logger.info(f"✓ Изображение сохранено в БД для сцены order={scene.order}")
    
    db.commit()
    logger.info(f"✅ _generate_draft_images_internal: Успешно завершено для book_id={data.book_id}, сгенерировано изображений: {len(results)}")

    return {"images": results}


@router.post("/generate_draft_images")
async def generate_draft_images(
    data: ImageRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует черновые изображения для всех сцен книги.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _generate_draft_images_internal(data, db, user_id)

