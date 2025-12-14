"""
Роутер для workflow создания и редактирования книг:
draft → editing → finalization → paid
"""
import logging
import json
from typing import Optional, Literal, Dict, Any
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from ..db import get_db
from ..models import Book, Child, Scene, Image
# Удалено: больше не используем Supabase
from ..services.deepseek_service import generate_text
from ..services.image_pipeline import generate_draft_image, generate_final_image
from ..services.local_file_service import upload_image_bytes
from ..core.deps import get_current_user
from datetime import datetime

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/books", tags=["books_workflow"])


class GenerateDraftRequest(BaseModel):
    """Запрос на генерацию черновика книги"""
    child_id: str  # UUID из Supabase children
    style: Literal["storybook", "cartoon", "pixar", "disney", "watercolor"] = "storybook"
    theme: Optional[str] = None
    narrator: Optional[str] = None
    writing_style: Optional[str] = None


class RegenerateSceneRequest(BaseModel):
    """Запрос на перегенерацию сцены"""
    scene_number: int
    detail_prompt: str


class UpdateTextRequest(BaseModel):
    """Запрос на обновление текста книги"""
    text_instructions: str


# ============================================
# 1. POST /books/generate_draft
# ============================================

@router.post("/generate_draft")
async def generate_draft(
    data: GenerateDraftRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создать черновик книги с AI-генерацией текста и изображений.
    
    Шаги:
    1. Проверить существование ребёнка
    2. Создать книгу со статусом "draft"
    3. Сгенерировать сюжет (сцены)
    4. Сгенерировать текст для всех сцен
    5. Сгенерировать промпты для изображений
    6. Сгенерировать черновые изображения
    7. Сохранить всё в pages JSON
    
    Returns:
        BookOut: Созданная книга с контентом
    """
    logger.info(f"📚 Начало генерации черновика книги для ребёнка {data.child_id}")
    
    # 1. Проверяем существование ребёнка в локальной БД
    try:
        # Преобразуем child_id в integer
        try:
            child_id_int = int(data.child_id)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Неверный формат child_id: {data.child_id}")
        
        child = db.query(Child).filter(Child.id == child_id_int).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с id={data.child_id} не найден")
        
        face_url = child.face_url
        logger.info(f"✓ Найден ребёнок в локальной БД: id={child.id}, name={child.name}")
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Ошибка при получении данных ребёнка: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка при получении данных ребёнка: {str(e)}")
    
    try:
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
        
        # 2. Генерируем сюжет
        from ..routers.plot import _create_plot_internal
        from ..routers.plot import CreatePlotRequest
        
        plot_request = CreatePlotRequest(child_id=child.id)  # Используем Integer id из PostgreSQL
        plot_result = await _create_plot_internal(plot_request, db, user_id)
        
        # Преобразуем book_id из строки в UUID
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(plot_result.book_id)
        except (ValueError, TypeError):
            raise HTTPException(status_code=500, detail=f"Неверный формат book_id: {plot_result.book_id}")
        
        # Получаем созданную книгу
        book = db.query(Book).filter(Book.id == book_uuid).first()
        if not book:
            raise HTTPException(status_code=500, detail="Не удалось найти созданную книгу")
        
        # Обновляем книгу с нашими параметрами
        book.status = "draft"
        book.theme = data.theme or book.theme
        book.writing_style = data.writing_style
        book.narrator = data.narrator
        book.pages = {}
        book.edit_history = {"operations": []}
        
        logger.info(f"✓ Книга создана: {book.id}")
        
        # 3. Получаем сцены
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        
        if not scenes:
            raise HTTPException(status_code=500, detail="Не удалось создать сцены")
        
        # 4. Генерируем текст для всех сцен
        from ..routers.text import _create_text_internal
        from ..routers.text import CreateTextRequest
        
        text_request = CreateTextRequest(book_id=str(book_uuid))
        text_result = await _create_text_internal(text_request, db, user_id)
        
        # 5. Генерируем промпты для изображений
        from ..routers.image_prompts import _create_image_prompts_internal
        from ..routers.image_prompts import CreateImagePromptsRequest
        
        prompts_request = CreateImagePromptsRequest(book_id=str(book_uuid))
        await _create_image_prompts_internal(prompts_request, db, user_id)
        
        # Обновляем сцены с промптами (обновляем список после генерации промптов)
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        
        # 6. Генерируем черновые изображения
        import uuid
        pages_data = []
        cover_url = None
        
        for scene in scenes:
            if not scene.image_prompt:
                continue
            
            # Формируем промпт с выбранным стилем
            enhanced_prompt = f"Visual style: {data.style}. {scene.image_prompt}"
            
            # Генерируем черновое изображение через image_pipeline
            image_url = await generate_draft_image(enhanced_prompt, style=data.style)
            
        # Сохраняем в Image модель
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
        
        # Сохраняем обложку (первая сцена)
        if scene.order == 1 and not cover_url:
            cover_url = image_url
        
        # Формируем данные страницы
        pages_data.append({
            "order": scene.order,
            "text": scene.text or "",
            "image_url": image_url,
            "image_prompt": scene.image_prompt or ""
        })
        
        # 7. Сохраняем всё в pages JSON и обновляем книгу
        book.pages = {"pages": pages_data}
        book.content = "\n\n".join([p.get("text", "") for p in pages_data])
        book.cover_url = cover_url
        book.prompt = f"Стиль: {data.style}, Тема: {data.theme or 'универсальная'}"
        book.ai_model = "openrouter-flux"
        book.variables_used = {
            "style": data.style,
            "theme": data.theme,
            "narrator": data.narrator,
            "writing_style": data.writing_style
        }
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "generate_draft",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "style": data.style,
                "theme": data.theme,
                "scenes_count": len(pages_data)
            }
        })
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ Черновик книги {book.id} создан успешно")
        
        from ..schemas.book import BookOut
        return BookOut.model_validate(book)
        
    except Exception as e:
        logger.error(f"✗ Ошибка при генерации черновика: {str(e)}", exc_info=True)
        db.rollback()
        # Удаляем книгу при ошибке (если она была создана)
        try:
            if 'book' in locals() and book:
                db.delete(book)
                db.commit()
        except Exception as cleanup_error:
            logger.warning(f"⚠ Не удалось удалить книгу при очистке: {str(cleanup_error)}")
        raise HTTPException(status_code=500, detail=f"Ошибка при генерации черновика: {str(e)}")


# ============================================
# 2. POST /books/{book_id}/regenerate_scene
# ============================================

@router.post("/{book_id}/regenerate_scene")
async def regenerate_scene(
    book_id: str,  # UUID как строка
    data: RegenerateSceneRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Перегенерировать изображение для одной сцены.
    
    Args:
        book_id: UUID книги
        data: scene_number и detail_prompt
        
    Returns:
        BookOut: Обновлённая книга
    """
    logger.info(f"🖼️ Перегенерация сцены {data.scene_number} для книги {book_id}")
    
    # Преобразуем строку book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем доступ к книге
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или доступ запрещён")
    
    if book.status != "draft":
        raise HTTPException(status_code=400, detail="Можно редактировать только книги в статусе 'draft'")
    
    # Получаем сцену
    scene = db.query(Scene).filter(
        Scene.book_id == book_uuid,
        Scene.order == data.scene_number
    ).first()
    
    if not scene:
        raise HTTPException(status_code=404, detail=f"Сцена {data.scene_number} не найдена")
    
    # Получаем стиль книги
    style = book.variables_used.get("style", "storybook") if book.variables_used else "storybook"
    
    # Формируем улучшенный промпт
    base_prompt = scene.image_prompt or ""
    enhanced_prompt = f"{base_prompt}. {data.detail_prompt}. Visual style: {style}."
    
    # Генерируем новое изображение через image_pipeline
    try:
        new_image_url = await generate_draft_image(enhanced_prompt, style=style)
        
        # Обновляем Image запись
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == data.scene_number
        ).first()
        
        if image_record:
            image_record.draft_url = new_image_url
        else:
            image_record = Image(
                book_id=book_uuid,
                scene_order=data.scene_number,
                draft_url=new_image_url
            )
            db.add(image_record)
        
        # Обновляем pages JSON
        if book.pages and "pages" in book.pages:
            pages_list = book.pages["pages"]
            for page in pages_list:
                if page.get("order") == data.scene_number:
                    page["image_url"] = new_image_url
                    page["detail_prompt"] = data.detail_prompt
                    break
        else:
            # Если pages пустой, создаём структуру
            if not book.pages:
                book.pages = {"pages": []}
            book.pages["pages"].append({
                "order": data.scene_number,
                "image_url": new_image_url,
                "detail_prompt": data.detail_prompt
            })
        
        # Сохраняем detail_prompt в книге
        book.detail_prompt = data.detail_prompt
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "regenerate_scene",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "scene_number": data.scene_number,
                "detail_prompt": data.detail_prompt,
                "new_image_url": new_image_url
            }
        })
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ Сцена {data.scene_number} перегенерирована")
        
        from ..schemas.book import BookOut
        return BookOut.model_validate(book)
        
    except Exception as e:
        logger.error(f"✗ Ошибка при перегенерации сцены: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при перегенерации сцены: {str(e)}")


# ============================================
# 3. POST /books/{book_id}/update_text
# ============================================

@router.post("/{book_id}/update_text")
async def update_text(
    book_id: str,  # UUID как строка
    data: UpdateTextRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Обновить текст книги на основе инструкций пользователя.
    
    Args:
        book_id: UUID книги
        data: text_instructions - инструкции для изменения текста
        
    Returns:
        BookOut: Обновлённая книга
    """
    logger.info(f"📝 Обновление текста книги {book_id}")
    
    # Преобразуем строку book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем доступ к книге
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или доступ запрещён")
    
    if book.status != "draft":
        raise HTTPException(status_code=400, detail="Можно редактировать только книги в статусе 'draft'")
    
    # Получаем сцены
    scenes = db.query(Scene).filter(
        Scene.book_id == book_uuid
    ).order_by(Scene.order).all()
    
    if not scenes:
        raise HTTPException(status_code=404, detail="Сцены не найдены")
    
    # Получаем профиль ребёнка для контекста
    child = db.query(Child).filter(Child.id == book.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Профиль ребёнка не найден")
    
    try:
        # Используем GPT для перегенерации текста на основе инструкций
        # Формируем промпт с инструкциями
        existing_text = book.content or ""
        
        prompt = f"""
Перепиши следующий текст детской книги согласно инструкциям пользователя.

Текущий текст:
{existing_text}

Инструкции пользователя:
{data.text_instructions}

Профиль ребёнка:
- Имя: {child.name}
- Возраст: {child.age}
- Интересы: {child.interests or 'не указано'}
- Характер: {child.personality or 'не указано'}

Требования:
1. Сохрани общую структуру и количество страниц
2. Следуй инструкциям пользователя
3. Адаптируй текст под возраст {child.age} лет
4. Верни текст в формате JSON с ключом "scenes", где каждый элемент - словарь с полями "order" и "text"
"""
        
        # Вызываем DeepSeek API
        response_text = await generate_text(prompt, json_mode=True, max_tokens=2000)
        
        # Парсим ответ
        try:
            # Пробуем найти JSON в ответе
            import re
            json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
            if json_match:
                response_data = json.loads(json_match.group())
            else:
                response_data = json.loads(response_text)
            
            new_scenes = response_data.get("scenes", [])
            
            # Обновляем текст в сценах
            for scene_data in new_scenes:
                scene_order = scene_data.get("order")
                new_text = scene_data.get("text", "")
                
                scene = next((s for s in scenes if s.order == scene_order), None)
                if scene:
                    scene.text = new_text
            
            # Обновляем content книги
            book.content = "\n\n".join([s.text for s in scenes if s.text])
            
            # Обновляем pages JSON
            if book.pages and "pages" in book.pages:
                pages_list = book.pages["pages"]
                for page in pages_list:
                    scene_order = page.get("order")
                    scene = next((s for s in scenes if s.order == scene_order), None)
                    if scene:
                        page["text"] = scene.text
            
            # Добавляем операцию в edit_history
            if not book.edit_history:
                book.edit_history = {"operations": []}
            
            book.edit_history["operations"].append({
                "type": "update_text",
                "timestamp": datetime.utcnow().isoformat(),
                "details": {
                    "instructions": data.text_instructions
                }
            })
            
            db.commit()
            db.refresh(book)
            
            logger.info(f"✓ Текст книги {book_id} обновлён")
            
            from ..schemas.book import BookOut
            return BookOut.model_validate(book)
            
        except json.JSONDecodeError as e:
            logger.error(f"✗ Ошибка парсинга JSON от GPT: {str(e)}")
            raise HTTPException(status_code=500, detail="Не удалось обработать ответ от AI")
            
    except Exception as e:
        logger.error(f"✗ Ошибка при обновлении текста: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при обновлении текста: {str(e)}")


# ============================================
# 4. POST /books/{book_id}/finalize
# ============================================

@router.post("/{book_id}/finalize")
async def finalize_book(
    book_id: str,  # UUID как строка
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Финализировать книгу: сгенерировать HD изображения и PDF.
    
    Шаги:
    1. Проверить статус книги (должна быть "draft")
    2. Сгенерировать финальные HD изображения для всех сцен
    3. Сгенерировать PDF из финальных изображений и текста
    4. Сохранить final_pdf_url и images_final
    5. Установить статус "final"
    
    Returns:
        BookOut: Финализированная книга
    """
    logger.info(f"✅ Финализация книги {book_id}")
    
    # Преобразуем строку book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем доступ к книге
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или доступ запрещён")
    
    if book.status != "draft":
        raise HTTPException(status_code=400, detail=f"Книга уже находится в статусе '{book.status}'. Можно финализировать только черновики.")
    
    try:
        # Получаем сцены
        scenes = db.query(Scene).filter(
            Scene.book_id == book_uuid
        ).order_by(Scene.order).all()
        
        if not scenes:
            raise HTTPException(status_code=404, detail="Сцены не найдены")
        
        # Получаем стиль
        from ..models import ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        final_style = theme_style.final_style if theme_style else (book.variables_used.get("style", "storybook") if book.variables_used else "storybook")
        
        # Генерируем финальные HD изображения
        import uuid
        import requests
        from ..routers.final_images import GenerateFinalImagesRequest, generate_final_images_endpoint
        
        # Получаем face_url ребёнка из PostgreSQL Child модели
        # Примечание: book.child_id это Integer из PostgreSQL, не UUID из Supabase
        # face_url должен быть получен из Child модели или из данных, переданных при создании книги
        face_url = None
        try:
            child = db.query(Child).filter(Child.id == book.child_id).first()
            # Если в Child нет face_url, можно попробовать получить из Supabase по имени
            # Но это не надежно, поэтому используем данные, которые уже есть
            if child:
                # face_url хранится в Supabase, не в PostgreSQL Child
                # Для получения face_url нужно использовать Supabase UUID, который мы не храним
                # Временно используем None, face_url должен быть передан при создании книги
                pass
        except Exception as e:
            logger.warning(f"Не удалось получить данные ребёнка: {e}")
            face_url = None
        
        # Генерируем финальные изображения через внутреннюю функцию
        from ..routers.final_images import _generate_final_images_internal
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
        
        final_images_result = await _generate_final_images_internal(
            book_id=str(book_uuid),  # Передаем как строку
            db=db,
            current_user_id=user_id,
            final_style=final_style
        )
        
        # Получаем финальные изображения из Image модели
        final_images_data = []
        for scene in scenes:
            image_record = db.query(Image).filter(
                Image.book_id == book_uuid,
                Image.scene_order == scene.order
            ).first()
            
            if image_record and image_record.final_url:
                final_images_data.append({
                    "order": scene.order,
                    "image_url": image_record.final_url
                })
        
        # Сохраняем images_final
        book.images_final = {"images": final_images_data}
        
        # Генерируем PDF (упрощённая версия - в реальности нужна библиотека для генерации PDF)
        # TODO: Интегрировать реальную генерацию PDF (например, reportlab или weasyprint)
        # Сейчас создаём placeholder URL
        pdf_url = f"/static/books/{book.id}/final.pdf"
        book.final_pdf_url = pdf_url
        
        # Устанавливаем статус "final"
        book.status = "final"
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "finalize",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "final_images_count": len(final_images_data),
                "pdf_url": pdf_url
            }
        })
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ Книга {book_id} финализирована")
        
        from ..schemas.book import BookOut
        return BookOut.model_validate(book)
        
    except Exception as e:
        logger.error(f"✗ Ошибка при финализации книги: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при финализации книги: {str(e)}")

