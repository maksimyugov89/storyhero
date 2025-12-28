from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
import requests
import uuid
import os
import logging

from ..db import get_db
from ..models import Scene, Image, ThemeStyle, Book, Child
from ..services.image_pipeline import generate_final_image
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["final_images"])


class GenerateFinalImagesRequest(BaseModel):
    book_id: str  # UUID как строка
    face_url: str
    style: Optional[str] = None  # опционально, будет браться из ThemeStyle


class RegenerateSceneRequest(BaseModel):
    book_id: str  # UUID как строка
    scene_order: int
    face_url: str
    style: str


async def _generate_final_images_internal(
    book_id: str,  # UUID как строка
    db: Session,
    current_user_id: str,
    final_style: str = None,
    face_url: Optional[str] = None,
    task_id: Optional[str] = None,
    child_photos: Optional[list[str]] = None
) -> dict:
    """
    Внутренняя функция для генерации финальных изображений.
    Может быть вызвана напрямую из других модулей.
    """
    # Преобразуем строку book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(book_id) if isinstance(book_id, str) else book_id
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем, что книга принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == current_user_id
    ).first()
    if not book:
        raise HTTPException(status_code=403, detail="Доступ запрещен: книга не принадлежит вам")
    
    # Получаем сцены
    scenes = db.query(Scene).filter(
        Scene.book_id == book_uuid
    ).order_by(Scene.order).all()
    
    if not scenes:
        raise HTTPException(status_code=404, detail="Сцены не найдены")
    
    # Получаем final_style из ThemeStyle, если не передан
    if not final_style:
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        if not theme_style:
            raise HTTPException(
                status_code=404,
                detail="Стиль для книги не выбран. Сначала вызовите /select_style"
            )
        final_style = theme_style.final_style
    
    results = []
    
    # Подсчитываем сцены с промптами (включая обложку с order=0)
    # Обложка должна быть первой, поэтому сортируем по order
    scenes_with_prompts = sorted([s for s in scenes if s.image_prompt], key=lambda x: x.order)
    
    # Обновляем прогресс с общим количеством изображений
    if task_id:
        from ..services.tasks import update_task_progress
        update_task_progress(task_id, {
            "total_images": len(scenes_with_prompts),
            "images_generated": 0
        })
    
    for idx, scene in enumerate(scenes_with_prompts, 1):
        # Проверяем, что книга все еще существует (может быть удалена во время генерации)
        book_check = db.query(Book).filter(Book.id == book_uuid).first()
        if not book_check:
            logger.warning(f"⚠️ Книга {book_id} была удалена во время генерации. Прерываем генерацию финальных изображений.")
            raise HTTPException(
                status_code=410,
                detail="Книга была удалена во время генерации. Генерация прервана."
            )
        
        # Формируем промпт с финальным стилем
        # Для обложки (order=0) добавляем название книги в промпт, чтобы оно было частью изображения
        # Усиливаем указание возраста и пола ребенка в промпте
        from ..models import Child
        child = db.query(Child).filter(Child.id == book_check.child_id).first() if book_check.child_id else None
        gender_text = "boy" if child and child.gender == "male" else "girl"
        age_emphasis = f"IMPORTANT: The child character must look exactly {child.age} years old {gender_text} with child proportions: large head relative to body, short legs, small hands, chubby cheeks, big eyes. The character must be a {gender_text}, not the opposite gender! " if child and child.age else ""
        
        # Используем sanitizer для обложки
        from ..services.scene_utils import is_cover_scene
        from ..services.prompt_sanitizer import build_cover_prompt
        
        if is_cover_scene(scene):
            # Для обложки используем специальную функцию build_cover_prompt
            # которая полностью очищает промпт от инструкций о тексте
            enhanced_prompt = build_cover_prompt(
                base_style=final_style,
                scene_prompt=scene.image_prompt or "",
                age_emphasis=age_emphasis
            )
            logger.info(f"🧼 Cover prompt built using sanitizer (order={scene.order})")
        else:
            # Для новых премиум стилей (marvel, dc, anime) используем специальные промпты
            if final_style in ['marvel', 'dc', 'anime']:
                from ..services.style_prompts import get_style_prompt
                enhanced_prompt = get_style_prompt(final_style, scene.image_prompt or "", is_cover=False)
                if age_emphasis:
                    enhanced_prompt = f"{age_emphasis}{enhanced_prompt}"
            else:
                # Для новых премиум стилей (marvel, dc, anime) используем специальные промпты
                if final_style in ['marvel', 'dc', 'anime']:
                    from ..services.style_prompts import get_style_prompt
                    enhanced_prompt = get_style_prompt(final_style, scene.image_prompt or "", is_cover=False)
                    if age_emphasis:
                        enhanced_prompt = f"{age_emphasis}{enhanced_prompt}"
                else:
                    # Для остальных стилей используем стандартный формат
                    enhanced_prompt = f"Visual style: {final_style}. {age_emphasis}{scene.image_prompt}"
        
        # Генерируем финальное изображение через image_pipeline с face swap
        # КРИТИЧЕСКИ ВАЖНО: Используем ВСЕ фотографии ребёнка для лучшего сходства!
        child_photo_path = None
        child_photo_paths_list = []
        
        # Получаем путь к фото ребёнка из face_url (для обратной совместимости)
        if face_url:
            # Извлекаем путь из URL (формат: http://host:port/static/children/{child_id}/filename.jpg)
            if "/static/" in face_url:
                relative_path = face_url.split("/static/", 1)[1]
                from ..services.storage import BASE_UPLOAD_DIR
                child_photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
        
        # Конвертируем все URL фотографий в пути к файлам
        if child_photos:
            from ..services.storage import BASE_UPLOAD_DIR
            for photo_url in child_photos:
                if isinstance(photo_url, str) and "/static/" in photo_url:
                    relative_path = photo_url.split("/static/", 1)[1]
                    photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                    if os.path.exists(photo_path):
                        child_photo_paths_list.append(photo_path)
                        logger.info(f"✓ Добавлена фотография для face swap: {photo_path}")
                    else:
                        logger.warning(f"⚠️ Файл фотографии не найден: {photo_path}")
        
        logger.info(f"🎭 Использование {len(child_photo_paths_list)} фотографий ребёнка для face swap на изображении сцены order={scene.order}")
        
        try:
            logger.info(f"🖼️ Генерация финального изображения для сцены order={scene.order} (сцена {idx}/{len(scenes_with_prompts)})")
            
            # Генерируем с таймаутом (максимум 5 минут на изображение)
            import asyncio
            try:
                # Для обложки передаем название книги отдельно
                book_title_for_cover = None
                if scene.order == 0:
                    book_title_for_cover = book_check.title
                
                # Определяем child_id для использования face profile
                child_id_for_face = None
                if child and child.id:
                    child_id_for_face = child.id
                
                final_url = await asyncio.wait_for(
                    generate_final_image(
                        enhanced_prompt, 
                        face_url=face_url,
                        child_photo_path=child_photo_path, 
                        child_photo_paths=child_photo_paths_list if child_photo_paths_list else None,
                        style=final_style,
                        book_title=book_title_for_cover,  # Передаем название для обложки
                        child_id=child_id_for_face,  # Передаем child_id для face profile
                        use_child_face=True  # Использовать face profile если доступен
                    ),
                    timeout=1800.0  # 30 минут
                )
                logger.info(f"✓ Финальное изображение сгенерировано для сцены order={scene.order}: {final_url}")
            except asyncio.TimeoutError:
                error_message = f"Таймаут при генерации финального изображения для сцены order={scene.order} (превышено 5 минут)"
                logger.error(f"❌ {error_message}")
                # Пропускаем это изображение и продолжаем
                if task_id:
                    from ..services.tasks import update_task_progress
                    update_task_progress(task_id, {
                        "images_generated": idx - 1,
                        "message": f"⚠ Пропущено изображение {idx}/{len(scenes_with_prompts)} из-за таймаута"
                    })
                continue  # Пропускаем это изображение
            logger.info(f"✓ Финальное изображение сгенерировано для сцены order={scene.order}: {final_url}")
        except HTTPException as e:
            # HTTPException имеет атрибут detail, извлекаем его
            error_message = f"Ошибка при генерации финального изображения для сцены order={scene.order}: {e.status_code}: {e.detail}"
            logger.error(f"❌ {error_message}", exc_info=True)
            raise
        except Exception as e:
            error_message = f"Ошибка при генерации финального изображения для сцены order={scene.order}: {str(e)}"
            logger.error(f"❌ {error_message}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=error_message
            )
        
        # Проверяем существование книги перед сохранением
        book_check = db.query(Book).filter(Book.id == book_uuid).first()
        if not book_check:
            logger.warning(f"⚠️ Книга {book_id} была удалена после генерации изображения для сцены order={scene.order}. Пропускаем сохранение.")
            continue  # Пропускаем сохранение, но продолжаем генерацию остальных
        
        # Сохраняем или обновляем запись в БД
        try:
            image_record = db.query(Image).filter(
                Image.book_id == book_uuid,
                Image.scene_order == scene.order
            ).first()
            
            if image_record:
                image_record.final_url = final_url
                image_record.style = final_style
            else:
                image_record = Image(
                    book_id=book_uuid,
                    scene_order=scene.order,
                    final_url=final_url,
                    style=final_style
                )
                db.add(image_record)
            
            db.commit()
            
            results.append({
                "order": scene.order,
                "image_url": final_url,
                "style": final_style
            })
            
            # Обновляем прогресс после успешной генерации
            if task_id:
                from ..services.tasks import update_task_progress
                update_task_progress(task_id, {
                    "images_generated": idx,
                    "message": f"Финальное изображение {idx}/{len(scenes_with_prompts)} готово ✓"
                })
        except Exception as db_error:
            logger.error(f"❌ Ошибка при сохранении изображения в БД для сцены order={scene.order}: {str(db_error)}", exc_info=True)
            db.rollback()
            # Продолжаем генерацию остальных изображений
            continue
    
    return {"images": results}


@router.post("/generate_final_images")
async def generate_final_images_endpoint(
    data: GenerateFinalImagesRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует финальные изображения для всех сцен книги
    """
    try:
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
        return await _generate_final_images_internal(
            book_id=data.book_id,
            db=db,
            current_user_id=user_id,
            final_style=data.style,
            face_url=data.face_url
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при генерации финальных изображений: {str(e)}")


@router.post("/regenerate_scene")
async def regenerate_scene_endpoint(
    data: RegenerateSceneRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Перегенерировать изображение для одной сцены
    """
    try:
        # Преобразуем строку book_id в UUID
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(data.book_id) if isinstance(data.book_id, str) else data.book_id
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
        
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
        
        # Проверяем, что книга принадлежит пользователю
        book = db.query(Book).filter(
            Book.id == book_uuid,
            Book.user_id == user_id
        ).first()
        if not book:
            raise HTTPException(status_code=403, detail="Доступ запрещен: книга не принадлежит вам")
        
        # Получаем сцену
        scene = db.query(Scene).filter(
            Scene.book_id == book_uuid,
            Scene.order == data.scene_order
        ).first()
        
        if not scene:
            raise HTTPException(status_code=404, detail="Сцена не найдена")
        
        if not scene.image_prompt:
            raise HTTPException(status_code=400, detail="У сцены нет промпта для изображения")
        
        # Получаем final_style из ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        if not theme_style:
            raise HTTPException(
                status_code=404,
                detail="Стиль для книги не выбран. Сначала вызовите /select_style"
            )
        
        final_style = theme_style.final_style
        
        # Формируем промпт с финальным стилем
        # Для новых премиум стилей (marvel, dc, anime) используем специальные промпты
        if final_style in ['marvel', 'dc', 'anime']:
            from ..services.style_prompts import get_style_prompt
            enhanced_prompt = get_style_prompt(final_style, scene.image_prompt or "", is_cover=False)
        else:
            enhanced_prompt = f"Visual style: {final_style}. {scene.image_prompt}"
        
        # Генерируем финальное изображение через image_pipeline с face swap
        # Получаем путь к фото ребёнка из child через book
        child_photo_path = None
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if child and child.face_url:
            # Извлекаем путь из URL (формат: http://host:port/static/children/{child_id}/filename.jpg)
            if "/static/" in child.face_url:
                relative_path = child.face_url.split("/static/", 1)[1]
                from ..services.storage import BASE_UPLOAD_DIR
                child_photo_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
        
        final_url = await generate_final_image(
            enhanced_prompt, 
            face_url=data.face_url,
            child_photo_path=child_photo_path, 
            style=final_style
        )
        
        # Обновляем запись в БД
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == data.scene_order
        ).first()
        
        if image_record:
            image_record.final_url = final_url
            image_record.style = final_style
        else:
            image_record = Image(
                book_id=book_uuid,
                scene_order=data.scene_order,
                final_url=final_url,
                style=final_style
            )
            db.add(image_record)
        
        db.commit()
        
        return {
            "order": data.scene_order,
            "image_url": final_url,
            "style": final_style
        }
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при перегенерации сцены: {str(e)}")

