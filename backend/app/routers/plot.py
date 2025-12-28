"""
Роутер для генерации сюжета книги через Gemini API.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
import json
import logging
import uuid

from ..db import get_db
from ..models import Child, Book, Scene
from ..services.gemini_service import generate_text
from ..services.tasks import update_task_progress
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["plot"])


class CreatePlotRequest(BaseModel):
    child_id: int
    num_pages: int = 20  # 10 или 20 страниц (сцен) без обложки
    theme: Optional[str] = None  # Тема книги (о чём будет книга)


class CreatePlotResponse(BaseModel):
    book_id: str  # UUID как строка
    title: str
    scenes: List[Dict[str, Any]]


async def _create_plot_internal(
    request: CreatePlotRequest,
    db: Session,
    user_id: str,
    task_id: Optional[str] = None  # Добавляем task_id для обновления progress
) -> CreatePlotResponse:
    """
    Внутренняя функция для генерации сюжета.
    Принимает user_id напрямую, без Depends().
    """
    try:
        logger.info(f"📖 _create_plot_internal: Начало для child_id={request.child_id}, num_pages={request.num_pages}, theme={request.theme}")
        
        # Получаем профиль ребёнка
        child = db.query(Child).filter(Child.id == request.child_id).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с id={request.child_id} не найден")
        
        # Проверяем права доступа
        if child.user_id != user_id:
            raise HTTPException(status_code=403, detail="Доступ запрещен: ребёнок не принадлежит вам")
        
        # Валидация num_pages
        if request.num_pages not in (10, 20):
            raise HTTPException(
                status_code=400,
                detail="Количество страниц должно быть 10 или 20"
            )
        
        num_scenes = request.num_pages
        
        # Подготавливаем профиль ребёнка для промпта
        child_profile = {
            "name": child.name,
            "age": child.age,
            "interests": child.interests or [],
            "fears": child.fears or [],
            "personality": child.personality or "",
            "moral": child.moral or "",
            "profile_json": child.profile_json or {}
        }
        
        # Формируем промпт с учётом темы книги
        theme_text = ""
        if request.theme and request.theme.strip():
            theme_text = f"\n\nТЕМА КНИГИ (обязательно использовать): {request.theme.strip()}\nКнига должна быть именно об этом событии, ситуации или приключении."
        
        system_prompt = """Ты — детский писатель. Создавай уникальные, захватывающие сюжеты для детских книг.
Верни результат ТОЛЬКО в формате JSON, без дополнительного текста."""
        
        user_prompt = f"""Профиль ребёнка: {json.dumps(child_profile, ensure_ascii=False)}{theme_text}

Сгенерируй уникальный сюжет книги.

ВАЖНО: Книга должна содержать РОВНО {num_scenes} сцен (страниц с текстом и иллюстрациями).
Обложка генерируется отдельно и НЕ входит в это число.
Итого в книге будет: 1 обложка + {num_scenes} страниц = {num_scenes + 1} страниц всего.

Формат JSON:
{{
  "title": "Название книги",
  "scenes": [
    {{
      "order": 1,
      "short_summary": "Краткое описание сцены (1-2 предложения)"
    }},
    {{
      "order": 2,
      "short_summary": "..."
    }}
  ]
}}

Количество сцен в массиве "scenes" должно быть РОВНО {num_scenes}."""
        
        # Вызываем Gemini API
        logger.info(f"📖 _create_plot_internal: Вызов Gemini API для child_id={request.child_id}")
        gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
        logger.info(f"📖 _create_plot_internal: Gemini API вернул ответ (длина: {len(gpt_response) if gpt_response else 0})")
        
        # Проверяем, что ответ не пустой
        if not gpt_response or not gpt_response.strip():
            logger.error(f"❌ _create_plot_internal: GPT вернул пустой ответ для child_id={request.child_id}")
            raise ValueError("GPT вернул пустой ответ")
        
        # Парсим JSON ответ
        try:
            plot_data = json.loads(gpt_response)
        except json.JSONDecodeError:
            # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
            import re
            json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
            if json_match:
                try:
                    plot_data = json.loads(json_match.group())
                except json.JSONDecodeError:
                    raise ValueError(f"Не удалось распарсить JSON из ответа GPT. Ответ: {gpt_response[:200]}")
            else:
                raise ValueError(f"Не удалось найти JSON в ответе GPT. Ответ: {gpt_response[:200]}")
        
        # Валидация структуры ответа
        if "title" not in plot_data:
            raise ValueError("GPT не вернул название книги")
        
        if "scenes" not in plot_data or not isinstance(plot_data["scenes"], list):
            raise ValueError("GPT не вернул массив сцен")
        
        scenes_list = plot_data["scenes"]
        if len(scenes_list) != num_scenes:
            logger.warning(f"⚠️ _create_plot_internal: GPT вернул {len(scenes_list)} сцен вместо {num_scenes}")
        
        # Создаём книгу
        book_id = uuid.uuid4()
        book = Book(
            child_id=request.child_id,
            user_id=user_id,
            title=plot_data.get("title", "Без названия"),
            theme=request.theme.strip() if request.theme and request.theme.strip() else None,
            status="draft"
        )
        book.id = book_id
        book.variables_used = plot_data
        
        db.add(book)
        db.flush()  # Получаем book.id
        
        # КРИТИЧЕСКИ ВАЖНО: Добавляем book_id в progress СРАЗУ после создания книги в БД
        # Это позволяет фронтенду перейти к книге максимально рано
        if task_id:
            update_task_progress(task_id, {
                "stage": "book_created",
                "current_step": 2,
                "total_steps": 7,
                "message": "Книга создана! Генерация сюжета...",
                "book_id": str(book_id)  # Преобразуем в строку для JSON
            })
            logger.info(f"✅ book_id добавлен в progress задачи {task_id} сразу после создания книги: {book_id}")
        
        # Создаём обложку (Scene с order=0)
        cover_scene = Scene(
            book_id=book_id,
            order=0,  # Обложка всегда имеет order=0
            short_summary=f"Обложка книги: {book.title}",
            text=f"Обложка книги '{book.title}'",
            image_prompt=f"Красивая обложка детской книги с названием '{book.title}'. Тема: {request.theme.strip() if request.theme and request.theme.strip() else 'Детская книга'}. Обложка должна быть яркой, привлекательной, с крупным названием книги в центре. Дизайн должен отражать тему книги и быть подходящим для детской аудитории. Используй яркие, насыщенные цвета, дружелюбные персонажи, волшебную атмосферу."
        )
        db.add(cover_scene)
        db.flush()
        
        # Создаём сцены
        created_scenes = [cover_scene]  # Начинаем с обложки
        for scene_data in scenes_list:
            order = scene_data.get("order")
            short_summary = scene_data.get("short_summary", "")
            
            if not order:
                continue
            
            scene = Scene(
                book_id=book_id,
                order=order,
                short_summary=short_summary
            )
            db.add(scene)
            created_scenes.append(scene)
        
        db.commit()
        db.refresh(book)
        
        logger.info(f"✓ _create_plot_internal: Сюжет создан для child_id={request.child_id}, book_id={book_id}, сцен: {len(created_scenes)}")
        
        # Формируем ответ
        scenes_response = [
            {
                "order": scene.order,
                "short_summary": scene.short_summary or ""
            }
            for scene in created_scenes
        ]
        
        return CreatePlotResponse(
            book_id=str(book_id),
            title=book.title,
            scenes=scenes_response
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"❌ _create_plot_internal: ValueError для child_id={request.child_id}: {str(e)}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"❌ _create_plot_internal: Exception для child_id={request.child_id}: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании сюжета: {str(e)}")


@router.post("/create_plot", response_model=CreatePlotResponse)
async def create_plot(
    request: CreatePlotRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует сюжет книги с помощью Gemini API.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _create_plot_internal(request, db, user_id)
