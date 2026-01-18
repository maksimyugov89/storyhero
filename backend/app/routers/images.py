from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
import requests

from ..db import get_db
from ..models import Scene, Image, ThemeStyle, Book
from ..services.image_pipeline import generate_draft_image
from ..services.storage import upload_image as upload_image_bytes
from ..core.deps import get_current_user

router = APIRouter(tags=["images"])


class ImageRequest(BaseModel):
    book_id: str  # UUID как строка
    face_url: str  # фото ребёнка


async def _generate_draft_images_internal(
    data: ImageRequest,
    db: Session,
    user_id: str,
    final_style: str = None,
    task_id: Optional[str] = None
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
    
    # Обновляем прогресс с общим количеством изображений в начале генерации
    if task_id:
        from ..services.tasks import update_task_progress
        update_task_progress(task_id, {
            "stage": "generating_draft_images",  # Устанавливаем stage
            "total_images": len(scenes_with_prompts),  # Общее количество изображений
            "images_generated": 0,  # Начинаем с 0
            "message": f"Начало генерации {len(scenes_with_prompts)} черновых изображений...",
            "book_id": str(data.book_id)  # Сохраняем book_id
        })
        logger.info(f"✅ Progress инициализирован: total_images={len(scenes_with_prompts)}")

    for idx, scene in enumerate(scenes_with_prompts, 1):
        logger.info(f"🖼️ Генерация изображения {idx}/{len(scenes_with_prompts)} для сцены order={scene.order}")
        
        # Обновляем прогресс ПЕРЕД генерацией (показываем, что начинаем генерацию)
        if task_id:
            from ..services.tasks import update_task_progress
            update_task_progress(task_id, {
                "stage": "generating_draft_images",  # Сохраняем stage
                "images_generated": idx - 1,  # Количество уже созданных (idx - 1)
                "total_images": len(scenes_with_prompts),  # Сохраняем total_images
                "message": f"Генерация изображения {idx}/{len(scenes_with_prompts)}...",
                "book_id": str(data.book_id)  # Сохраняем book_id
            })
        
        # Формируем промпт с финальным стилем (если есть)
        # КРИТИЧНО: Для обложки используем sanitizer, чтобы убрать все инструкции о тексте
        # Усиливаем указание возраста ребенка в промпте
        # ВАЖНО: НЕ используем слово "IMPORTANT:" - оно попадает в изображение как текст!
        from ..models import Child
        child = db.query(Child).filter(Child.id == book.child_id).first() if book.child_id else None
        age_emphasis = f"The child character must look exactly {child.age} years old with child proportions: large head relative to body, short legs, small hands, chubby cheeks, big eyes. " if child and child.age else ""
        
        # КРИТИЧНО: Для ВСЕХ сцен используем sanitizer, чтобы убрать метаданные,
        # которые Pollinations.ai рендерит как текст на изображении!
        # Убираем: "Visual style:", "IMPORTANT:", имена, возраст, инструкции о пропорциях
        from ..services.scene_utils import is_cover_scene
        from ..services.prompt_sanitizer import build_cover_prompt, sanitize_scene_prompt
        
        if is_cover_scene(scene):
            # Для обложки используем специальный sanitizer - убирает ВСЕ инструкции о тексте
            enhanced_prompt = build_cover_prompt(
                base_style=final_style or "storybook",
                scene_prompt=scene.image_prompt or "",
                age_emphasis=age_emphasis
            )
            logger.info(f"🧼 Cover draft prompt sanitized (order={scene.order})")
        else:
            # КРИТИЧНО: Для обычных сцен тоже используем sanitizer!
            # Pollinations.ai рендерит "Visual style:", "IMPORTANT:", имена как текст на изображении!
            if final_style:
                # Для новых премиум стилей (marvel, dc, anime) используем специальные промпты
                if final_style in ['marvel', 'dc', 'anime']:
                    from ..services.style_prompts import get_style_prompt
                    base_prompt = get_style_prompt(final_style, scene.image_prompt or "", is_cover=False)
                    # Санитизируем результат - убираем метаданные
                    enhanced_prompt = sanitize_scene_prompt(base_prompt, style=None)  # стиль уже в промпте
                else:
                    # Санитизируем промпт и добавляем стиль в конец (не в начало!)
                    enhanced_prompt = sanitize_scene_prompt(
                        scene.image_prompt or "",
                        style=final_style
                    )
            else:
                enhanced_prompt = sanitize_scene_prompt(scene.image_prompt or "", style="storybook")
                final_style = "storybook"  # дефолтный стиль
            
            logger.info(f"🧼 Scene prompt sanitized (order={scene.order}): {enhanced_prompt[:100]}...")
        
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
        try:
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
            
            # КРИТИЧЕСКИ ВАЖНО: Сохраняем каждое изображение сразу, чтобы не потерять прогресс
            db.commit()
            logger.info(f"✓ Изображение сохранено в БД для сцены order={scene.order}")
        except Exception as db_error:
            logger.error(f"❌ Ошибка при сохранении изображения в БД для сцены order={scene.order}: {str(db_error)}", exc_info=True)
            db.rollback()
            # Продолжаем генерацию остальных изображений
            continue
        
        results.append({"order": scene.order, "image_url": image_url})
        
        # Обновляем прогресс ПОСЛЕ сохранения изображения
        if task_id:
            from ..services.tasks import update_task_progress
            update_task_progress(task_id, {
                "stage": "generating_draft_images",  # Сохраняем stage
                "images_generated": idx,  # Количество созданных изображений (idx, так как уже сохранено)
                "total_images": len(scenes_with_prompts),  # Сохраняем total_images
                "message": f"Изображение {idx}/{len(scenes_with_prompts)} создано",
                "book_id": str(data.book_id)  # Сохраняем book_id
            })
    
    logger.info(f"✅ _generate_draft_images_internal: Успешно завершено для book_id={data.book_id}, сгенерировано изображений: {len(results)}")
    
    # Финальное обновление progress после завершения всех изображений
    if task_id:
        from ..services.tasks import update_task_progress
        update_task_progress(task_id, {
            "stage": "generating_draft_images",  # Остаемся на этом этапе до следующего шага
            "images_generated": len(scenes_with_prompts),  # Все изображения созданы
            "total_images": len(scenes_with_prompts),  # Общее количество
            "message": f"Все черновые изображения созданы ({len(scenes_with_prompts)}/{len(scenes_with_prompts)})",
            "book_id": str(data.book_id)  # Сохраняем book_id
        })
        logger.info(f"✅ Progress обновлен: все {len(scenes_with_prompts)} черновых изображений созданы")

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

