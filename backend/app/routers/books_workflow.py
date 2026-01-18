"""
Роутер для workflow создания и редактирования книг:
draft → editing → finalization → paid
"""
import logging
import json
import os
from typing import Optional, Dict, Any, List
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from ..db import get_db
from ..models import Book, Child, Scene, Image, ThemeStyle
from ..services.gemini_service import generate_text
from ..services.image_pipeline import generate_draft_image, generate_final_image
from ..services.storage import upload_image as upload_image_bytes
from ..core.deps import get_current_user
from ..services.tasks import create_task, update_task_progress
from datetime import datetime
from ..config.styles import (
    normalize_style,
    is_style_known,
    is_premium_style,
    check_style_access,
    deactivate_if_expired,
    ALL_STYLES,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/books", tags=["books_workflow"])


class GenerateDraftRequest(BaseModel):
    """Запрос на генерацию черновика книги"""
    child_id: str  # ID ребёнка (Integer)
    style: str = "classic"
    num_pages: int = 20  # 10 или 20 страниц (сцен) без обложки
    theme: Optional[str] = None
    narrator: Optional[str] = None
    writing_style: Optional[str] = None


class RegenerateSceneRequest(BaseModel):
    """Запрос на перегенерацию сцены"""
    # Поддерживаем оба варианта для совместимости с фронтендом
    scene_number: Optional[int] = None
    scene_index: Optional[int] = None  # Альтернативное имя от фронтенда
    detail_prompt: Optional[str] = None
    instruction: Optional[str] = None  # Альтернативное имя от фронтенда
    
    def get_scene_number(self) -> int:
        """Возвращает номер сцены из любого поля"""
        if self.scene_number is not None:
            return self.scene_number
        if self.scene_index is not None:
            return self.scene_index
        raise ValueError("scene_number или scene_index обязательны")
    
    def get_detail_prompt(self) -> str:
        """Возвращает промпт из любого поля"""
        if self.detail_prompt:
            return self.detail_prompt
        if self.instruction:
            return self.instruction
        raise ValueError("detail_prompt или instruction обязательны")


class UpdateTextRequest(BaseModel):
    """Запрос на обновление текста книги"""
    text_instructions: str


class UpdateSceneTextRequest(BaseModel):
    """Запрос на обновление текста конкретной сцены"""
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
    
    try:
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")

        # 1. Проверяем существование ребёнка в локальной БД + права доступа
        # Преобразуем child_id в integer
        try:
            child_id_int = int(data.child_id)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Неверный формат child_id: {data.child_id}")

        child = db.query(Child).filter(Child.id == child_id_int).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с id={data.child_id} не найден")

        if child.user_id != user_id:
            raise HTTPException(status_code=403, detail="Доступ запрещён. Этот ребёнок принадлежит другому пользователю.")

        face_url = child.face_url
        logger.info(f"✓ Найден ребёнок в локальной БД: id={child.id}, name={child.name}")

        # 1.1 Валидация num_pages (синхронизация с фронтендом: только 10/20)
        if data.num_pages not in (10, 20):
            raise HTTPException(status_code=400, detail="Количество страниц должно быть 10 или 20")

        # 1.2 Нормализация/валидация стиля (25 стилей)
        normalized_style = normalize_style(data.style)
        if not is_style_known(normalized_style):
            raise HTTPException(
                status_code=400,
                detail=f"Неизвестный стиль: {data.style}. Доступные: {', '.join(ALL_STYLES)}"
            )

        # 1.3 Проверка подписки для премиум-стилей (до старта тяжёлых шагов)
        deactivate_if_expired(db, user_id)
        if is_premium_style(normalized_style) and not check_style_access(db, user_id, normalized_style):
            raise HTTPException(
                status_code=403,
                detail="Этот стиль доступен только по подписке. Оформите подписку за 199 ₽/мес"
            )
        
        # 2. Генерируем сюжет
        from ..routers.plot import _create_plot_internal
        from ..routers.plot import CreatePlotRequest
        
        plot_request = CreatePlotRequest(child_id=child.id, num_pages=data.num_pages, theme=data.theme.strip() if data.theme and data.theme.strip() else None)  # Используем Integer id из PostgreSQL
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
            if not scene.image_prompt or not scene.image_prompt.strip():
                logger.warning(f"⚠️ Пропущена сцена order={scene.order} без промпта для book_id={book_uuid}")
                # Создаем fallback промпт для сцены без промпта
                scene.image_prompt = f"Illustration for scene {scene.order}: {scene.text[:200] if scene.text else scene.short_summary or 'story scene'}"
                db.commit()
                logger.info(f"✅ Создан fallback промпт для сцены order={scene.order}")
            
            # Формируем промпт с выбранным стилем
            # КРИТИЧНО: НЕ используем "Visual style:" - эта фраза попадает в изображение как текст!
            enhanced_prompt = f"{normalized_style} style. {scene.image_prompt}"
            
            # Генерируем черновое изображение через image_pipeline
            image_url = await generate_draft_image(enhanced_prompt, style=normalized_style)
            
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
        book.prompt = f"Стиль: {normalized_style}, Тема: {data.theme or 'универсальная'}"
        book.ai_model = "fal-ai-flux-pro"
        book.variables_used = {
            "style": normalized_style,
            "theme": data.theme,
            "narrator": data.narrator,
            "writing_style": data.writing_style,
            "num_pages": data.num_pages,
        }
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "generate_draft",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "style": normalized_style,
                "theme": data.theme,
                "scenes_count": len(pages_data),
                "num_pages": data.num_pages,
            }
        })
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ Черновик книги {book.id} создан успешно")
        
        from ..schemas.book import BookOut
        return BookOut.model_validate(book)
        
    except HTTPException:
        # Не заворачиваем в 500 — возвращаем корректный статус/сообщение
        db.rollback()
        raise
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
    # Получаем номер сцены и промпт (поддерживаем оба варианта)
    try:
        scene_number = data.get_scene_number()
        detail_prompt = data.get_detail_prompt()
    except ValueError as e:
        raise HTTPException(status_code=422, detail=str(e))
    
    logger.info(f"🖼️ Перегенерация сцены {scene_number} для книги {book_id}")
    
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
        Scene.order == scene_number
    ).first()
    
    if not scene:
        raise HTTPException(status_code=404, detail=f"Сцена {scene_number} не найдена")
    
    # Получаем стиль книги
    style_raw = book.variables_used.get("style", "classic") if book.variables_used else "classic"
    style = normalize_style(style_raw)
    if not is_style_known(style):
        style = "classic"

    # Проверка подписки для премиум стиля при перегенерации
    deactivate_if_expired(db, user_id)
    if is_premium_style(style) and not check_style_access(db, user_id, style):
        raise HTTPException(
            status_code=403,
            detail="Этот стиль доступен только по подписке. Оформите подписку за 199 ₽/мес"
        )
    
    # Формируем улучшенный промпт
    base_prompt = scene.image_prompt or ""
    enhanced_prompt = f"{base_prompt}. {detail_prompt}. Visual style: {style}."
    
    # Генерируем новое изображение через image_pipeline
    try:
        new_image_url = await generate_draft_image(enhanced_prompt, style=style)
        
        # Обновляем Image запись
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == scene_number
        ).first()
        
        if image_record:
            image_record.draft_url = new_image_url
        else:
            image_record = Image(
                book_id=book_uuid,
                scene_order=scene_number,
                draft_url=new_image_url
            )
            db.add(image_record)
        
        # Обновляем pages JSON
        if book.pages and "pages" in book.pages:
            pages_list = book.pages["pages"]
            for page in pages_list:
                if page.get("order") == scene_number:
                    page["image_url"] = new_image_url
                    page["detail_prompt"] = detail_prompt
                    break
        else:
            # Если pages пустой, создаём структуру
            if not book.pages:
                book.pages = {"pages": []}
            book.pages["pages"].append({
                "order": scene_number,
                "image_url": new_image_url,
                "detail_prompt": detail_prompt
            })
        
        # Сохраняем detail_prompt в книге
        book.detail_prompt = detail_prompt
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "regenerate_scene",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "scene_number": scene_number,
                "detail_prompt": detail_prompt,
                "new_image_url": new_image_url
            }
        })
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ Сцена {scene_number} перегенерирована")
        
        # Получаем image_url из Image модели (если есть)
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == scene_number
        ).first()
        
        image_url = None
        if image_record:
            image_url = image_record.final_url or image_record.draft_url
        
        # Возвращаем обновлённую сцену в формате, ожидаемом фронтендом
        return {
            "id": str(scene.id),
            "book_id": str(scene.book_id),
            "order": scene.order,
            "short_summary": scene.short_summary or "",
            "text": scene.text,
            "image_prompt": scene.image_prompt,
            "draft_url": image_record.draft_url if image_record else None,
            "image_url": image_url
        }
        
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
        
        # Вызываем Gemini API
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
# 4. POST /books/{book_id}/scenes/{scene_index}/update_text
# ============================================

@router.post("/{book_id}/scenes/{scene_index}/update_text")
async def update_scene_text(
    book_id: str,  # UUID как строка
    scene_index: int,  # Порядковый номер сцены (order)
    data: UpdateSceneTextRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Обновить текст конкретной сцены на основе инструкций пользователя.
    
    Args:
        book_id: UUID книги
        scene_index: Порядковый номер сцены (order)
        data: text_instructions - инструкции для изменения текста
        
    Returns:
        {
            "id": str(scene.id),
            "book_id": str(scene.book_id),
            "order": scene.order,
            "text": scene.text,
            "short_summary": scene.short_summary,
            "image_prompt": scene.image_prompt,
            "image_url": None  # Будет заполнено из Image модели
        }
    """
    logger.info(f"📝 Обновление текста сцены {scene_index} книги {book_id}")
    
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
    
    # Проверяем статус книги (можно редактировать в draft или editing)
    if book.status not in ["draft", "editing"]:
        raise HTTPException(
            status_code=400,
            detail=f"Редактирование запрещено для статуса '{book.status}'. Можно редактировать только книги в статусе 'draft' или 'editing'."
        )
    
    # Получаем сцену
    scene = db.query(Scene).filter(
        Scene.book_id == book_uuid,
        Scene.order == scene_index
    ).first()
    
    if not scene:
        raise HTTPException(status_code=404, detail=f"Сцена {scene_index} не найдена")
    
    # Получаем профиль ребёнка
    child = db.query(Child).filter(Child.id == book.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Профиль ребёнка не найден")
    
    try:
        # Проверяем, является ли инструкция прямым указанием использовать конкретный текст
        # Формат: "Использовать этот текст: <текст>"
        text_instructions = data.text_instructions.strip()
        if text_instructions.startswith("Использовать этот текст:"):
            # Извлекаем текст напрямую без вызова AI
            new_text = text_instructions.replace("Использовать этот текст:", "").strip()
            logger.info(f"📝 Прямое сохранение текста для сцены {scene_index} (без генерации через AI)")
        else:
            # Генерируем новый текст через Gemini
            current_text = scene.text or scene.short_summary or ""
            
            prompt = f"""Перепиши следующий текст сцены детской книги согласно инструкциям.

Текущий текст сцены:
{current_text}

Инструкции пользователя:
{data.text_instructions}

Профиль ребёнка:
- Имя: {child.name if child else 'Герой'}
- Возраст: {child.age if child else 7} лет
- Интересы: {', '.join(child.interests) if child and child.interests else 'не указано'}
- Характер: {child.personality if child and child.personality else 'не указано'}

Требования:
1. Следуй инструкциям пользователя
2. Сохрани общий стиль и тон текста
3. Адаптируй текст под возраст {child.age if child else 7} лет
4. Верни ТОЛЬКО новый текст сцены, без дополнительных пояснений или комментариев."""
            
            new_text = await generate_text(prompt, json_mode=False, max_tokens=1000)
            new_text = new_text.strip()
        
        if not new_text or len(new_text) < 10:
            raise HTTPException(
                status_code=500,
                detail="AI вернул пустой или слишком короткий текст"
            )
        
        # Обновляем сцену
        scene.text = new_text
        scene.short_summary = new_text[:200] if len(new_text) > 200 else new_text
        
        logger.info(f"📝 Обновление сцены {scene_index}: text длина={len(new_text)}, short_summary длина={len(scene.short_summary)}")
        
        # Обновляем content книги (собираем все тексты сцен)
        scenes = db.query(Scene).filter(
            Scene.book_id == book_uuid
        ).order_by(Scene.order).all()
        book.content = "\n\n".join([s.text for s in scenes if s.text])
        
        # Обновляем pages JSON, если он существует
        if book.pages and "pages" in book.pages:
            pages_list = book.pages["pages"]
            for page in pages_list:
                if page.get("order") == scene_index:
                    page["text"] = new_text
                    break
        
        # Добавляем операцию в edit_history
        if not book.edit_history:
            book.edit_history = {"operations": []}
        
        book.edit_history["operations"].append({
            "type": "update_scene_text",
            "timestamp": datetime.utcnow().isoformat(),
            "details": {
                "scene_index": scene_index,
                "instructions": data.text_instructions
            }
        })
        
        db.commit()
        db.refresh(scene)
        
        logger.info(f"✓ Текст сцены {scene_index} обновлён для книги {book_id}")
        
        # Получаем image_url из Image модели (если есть)
        image_record = db.query(Image).filter(
            Image.book_id == book_uuid,
            Image.scene_order == scene_index
        ).first()
        
        image_url = None
        if image_record:
            image_url = image_record.final_url or image_record.draft_url
        
        # Возвращаем обновлённую сцену
        return {
            "id": str(scene.id),
            "book_id": str(scene.book_id),
            "order": scene.order,
            "text": scene.text,
            "short_summary": scene.short_summary,
            "image_prompt": scene.image_prompt,
            "image_url": image_url
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка при обновлении текста сцены: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при обновлении текста сцены: {str(e)}"
        )


# ============================================
# 5. POST /books/{book_id}/generate_final_version
# ============================================

class GenerateFinalVersionResponse(BaseModel):
    """Ответ на запрос генерации финальной версии"""
    task_id: str
    message: str
    book_id: str
    child_id: Optional[str] = None  # Добавлено для совместимости с фронтендом


async def generate_final_version_task(
    book_id: str,
    user_id: str,
    db: Session,
    task_id: Optional[str] = None
):
    """
    Асинхронная задача для генерации финальной версии книги.
    Генерирует финальные изображения для всех сцен с учетом изменений пользователя.
    
    Args:
        book_id: ID книги (UUID как строка)
        user_id: ID пользователя
        db: Сессия БД
        task_id: ID задачи для отслеживания прогресса
    """
    from uuid import UUID as UUIDType
    
    try:
        # Преобразуем book_id в UUID
        try:
            book_uuid = UUIDType(book_id) if isinstance(book_id, str) else book_id
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
        
        # Обновляем прогресс
        if task_id:
            update_task_progress(task_id, {
                "stage": "preparing",
                "current_step": 1,
                "total_steps": 3,
                "message": "Подготовка данных для генерации финальной версии..."
            })
        
        # Проверяем, что книга существует и принадлежит пользователю
        book = db.query(Book).filter(
            Book.id == book_uuid,
            Book.user_id == str(user_id)
        ).first()
        
        if not book:
            raise HTTPException(status_code=404, detail="Книга не найдена или доступ запрещён")
        
        # Проверяем статус книги
        if book.status not in ['draft', 'editing']:
            raise HTTPException(
                status_code=422,
                detail=f"Книга не может быть отправлена на генерацию. Текущий статус: {book.status}"
            )
        
        # Получаем все сцены книги
        scenes = db.query(Scene).filter(
            Scene.book_id == book_uuid
        ).order_by(Scene.order).all()
        
        if not scenes:
            raise HTTPException(
                status_code=422,
                detail="У книги нет сцен для генерации"
            )
        
        # Получаем данные ребенка
        child = None
        face_url = None
        child_photos = []
        
        if book.child_id:
            child = db.query(Child).filter(Child.id == book.child_id).first()
            if child:
                face_url = child.face_url
                # Получаем все фотографии ребенка через функцию из children.py
                try:
                    from ..routers.children import _get_child_photos_urls
                    child_photos = _get_child_photos_urls(book.child_id)
                    logger.info(f"📸 Получено {len(child_photos)} фотографий ребёнка для face swap")
                except Exception as e:
                    logger.warning(f"⚠️ Не удалось получить фотографии ребёнка: {str(e)}")
                    child_photos = []
        
        # Получаем стиль книги
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        final_style = theme_style.final_style if theme_style else 'disney'
        
        # Обновляем прогресс
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_images",
                "current_step": 2,
                "total_steps": 3,
                "message": f"Генерация финальных изображений для {len(scenes)} сцен..."
            })
        
        logger.info(f"🎨 Начало генерации финальной версии для книги {book_id}")
        logger.info(f"   Стиль: {final_style}")
        logger.info(f"   Сцен: {len(scenes)}")
        logger.info(f"   Лицо ребенка: {'есть' if face_url else 'нет'}")
        
        # Используем существующую функцию генерации финальных изображений
        from ..routers.final_images import _generate_final_images_internal
        
        result = await _generate_final_images_internal(
            book_id=book_id,
            db=db,
            current_user_id=str(user_id),
            final_style=final_style,
            face_url=face_url,
            task_id=task_id,
            child_photos=child_photos if child_photos else None
        )
        
        # Обновляем статус книги на 'editing' после завершения генерации
        book.status = 'editing'
        db.commit()
        
        # Обновляем прогресс
        if task_id:
            update_task_progress(task_id, {
                "stage": "completed",
                "current_step": 3,
                "total_steps": 3,
                "message": "Генерация финальной версии завершена успешно!"
            })
        
        logger.info(f"✅ Генерация финальной версии для книги {book_id} завершена")
        
        return {
            "book_id": str(book_id),
            "status": "editing",
            "images_generated": len(result.get("generated_images", []))
        }
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Ошибка в generate_final_version_task: {str(e)}", exc_info=True)
        if task_id:
            update_task_progress(task_id, {
                "stage": "error",
                "message": f"Ошибка генерации: {str(e)}"
            })
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка генерации финальной версии: {str(e)}"
        )


@router.post("/{book_id}/generate_final_version", response_model=GenerateFinalVersionResponse)
async def generate_final_version(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Отправить книгу на генерацию финальной версии.
    
    Генерирует финальные изображения для всех сцен с учетом всех изменений пользователя:
    - Текущий текст сцен (после всех правок)
    - Перегенерированные изображения (если пользователь их изменил)
    - Лицо ребенка из child.face_url
    - Стиль книги (из ThemeStyle или дефолтный 'disney')
    
    Требования:
    - Книга должна иметь статус 'draft' или 'editing'
    - У книги должны быть сцены
    
    Returns:
        GenerateFinalVersionResponse: task_id для отслеживания прогресса
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Преобразуем book_id в UUID
    from uuid import UUID as UUIDType
    try:
        book_uuid = UUIDType(book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем, что книга существует и принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == str(user_id)
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или доступ запрещён")
    
    # Проверяем статус книги
    if book.status not in ['draft', 'editing']:
        raise HTTPException(
            status_code=422,
            detail=f"Книга не может быть отправлена на генерацию. Текущий статус: {book.status}. Ожидается 'draft' или 'editing'."
        )
    
    # Проверяем наличие сцен
    scenes = db.query(Scene).filter(Scene.book_id == book_uuid).all()
    if not scenes:
        raise HTTPException(
            status_code=422,
            detail="У книги нет сцен для генерации"
        )
    
    # Проверяем наличие child_id
    if not book.child_id:
        raise HTTPException(
            status_code=422,
            detail="У книги не указан профиль ребёнка (child_id)"
        )
    
    # Проверяем, нет ли уже запущенной задачи для этой книги
    from ..services.tasks import find_running_task
    existing_task = find_running_task({
        "type": "generate_final_version",
        "book_id": str(book_uuid),
        "user_id": str(user_id)
    })
    
    if existing_task:
        logger.warning(f"⚠️ generate_final_version: Уже есть активная задача {existing_task} для book_id={book_id}")
        return GenerateFinalVersionResponse(
            task_id=existing_task,
            message="Генерация финальной версии уже запущена",
            book_id=book_id,
            child_id=str(book.child_id)  # child_id уже проверен выше
        )
    
    # Создаем задачу генерации
    task_id = create_task(
        generate_final_version_task,
        book_id=book_id,
        user_id=str(user_id),
        db=db,
        meta={
            "type": "generate_final_version",
            "book_id": str(book_uuid),
            "user_id": str(user_id)
        },
        task_id=None
    )
    
    logger.info(f"✅ Задача генерации финальной версии создана: task_id={task_id}, book_id={book_id}")
    logger.warning(f"⚠️  ВАЖНО: Задача {task_id} запущена. Не перезапускайте контейнер до завершения генерации!")
    
    return GenerateFinalVersionResponse(
        task_id=task_id,
        message="Генерация финальной версии запущена",
        book_id=book_id,
        child_id=str(book.child_id)  # child_id уже проверен выше
    )


# ============================================
# 6. POST /books/{book_id}/finalize
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
        face_url = None
        try:
            child = db.query(Child).filter(Child.id == book.child_id).first()
            if child:
                face_url = child.face_url
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
        
        # КРИТИЧНО: Генерируем PDF используя существующий скрипт
        logger.info(f"📄 Генерация PDF для книги {book_id}...")
        try:
            from ..scripts.generate_pdf_for_book import generate_pdf
            
            # Генерируем PDF (функция возвращает exit code 0 или 1)
            exit_code = await generate_pdf(str(book_uuid))
            
            if exit_code == 0:
                # Обновляем книгу из БД, чтобы получить актуальный final_pdf_url
                db.refresh(book)
                if book.final_pdf_url:
                    pdf_url = book.final_pdf_url
                    logger.info(f"✅ PDF успешно сгенерирован: {pdf_url}")
                else:
                    # Если URL не обновился, создаём placeholder
                    logger.warning(f"⚠️ PDF сгенерирован, но URL не обновлён, создаём placeholder")
                    pdf_url = f"/static/books/{book.id}/final.pdf"
                    book.final_pdf_url = pdf_url
            else:
                # Если генерация не удалась, создаём placeholder
                logger.warning(f"⚠️ PDF не сгенерирован (exit_code={exit_code}), создаём placeholder")
                pdf_url = f"/static/books/{book.id}/final.pdf"
                book.final_pdf_url = pdf_url
        except Exception as pdf_error:
            logger.error(f"❌ Ошибка при генерации PDF: {pdf_error}", exc_info=True)
            # В случае ошибки создаём placeholder, чтобы не блокировать финализацию
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

