from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Dict, Any
import json

from ..db import get_db
from ..models import Child, Book, Scene
from ..services.deepseek_service import generate_text
from ..core.deps import get_current_user

router = APIRouter(prefix="", tags=["plot"])


class CreatePlotRequest(BaseModel):
    child_id: int
    num_pages: int = 20  # 10 или 20 страниц (сцен) без обложки


class SceneResponse(BaseModel):
    order: int
    short_summary: str


class CreatePlotResponse(BaseModel):
    book_id: str  # UUID как строка для JSON
    scenes: List[SceneResponse]


async def _create_plot_internal(
    request: CreatePlotRequest,
    db: Session,
    user_id: str
) -> CreatePlotResponse:
    """
    Внутренняя функция для создания сюжета книги.
    Принимает user_id напрямую, без Depends().
    """
    try:
        # Получаем профиль ребёнка из БД
        child = db.query(Child).filter(Child.id == request.child_id).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с id={request.child_id} не найден")
        
        # Подготавливаем профиль для промпта
        child_profile = {
            "name": child.name,
            "age": child.age,
            "interests": child.interests or [],
            "fears": child.fears or [],
            "personality": child.personality or "",
            "moral": child.moral or "",
            "profile_json": child.profile_json or {}
        }
        
        # Формируем промпты для GPT
        system_prompt = """Ты — профессиональный детский писатель. Создаёшь уникальные сюжеты, которые никогда не повторяются."""
        
        # Валидация количества страниц (синхронизация с фронтендом)
        if request.num_pages not in (10, 20):
            raise HTTPException(status_code=400, detail="Количество страниц должно быть 10 или 20")

        num_scenes = request.num_pages  # Количество сцен = количество страниц
        
        user_prompt = f"""Профиль ребёнка: {json.dumps(child_profile, ensure_ascii=False)}

Сгенерируй уникальный сюжет книги.

ВАЖНО: Книга должна содержать РОВНО {num_scenes} сцен (страниц с текстом и иллюстрациями).
Обложка генерируется отдельно и НЕ входит в это число.
Итого в книге будет: 1 обложка + {num_scenes} страниц = {num_scenes + 1} страниц всего.

Формат ответа строго в JSON:
{{
  "title": "...",
  "theme": "...",
  "moral": "...",
  "scenes": [
    {{
      "order": 1,
      "short_summary": "..."
    }},
    ...
  ]
}}

Количество сцен в массиве "scenes" должно быть РОВНО {num_scenes}."""
        
        # Вызываем DeepSeek API
        gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
        
        # Проверяем, что ответ не пустой
        if not gpt_response or not gpt_response.strip():
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
        
        # Создаем запись Book в БД
        book = Book(
            child_id=request.child_id,
            user_id=user_id,
            title=plot_data.get("title", "Без названия"),
            theme=plot_data.get("theme", ""),
            status="draft"
        )
        # Сохраняем plot_data в variables_used (JSONB поле) для хранения всей информации о сюжете
        book.variables_used = plot_data
        
        db.add(book)
        db.flush()  # Получаем book.id
        
        # Создаем записи Scene
        scenes_data = plot_data.get("scenes", [])
        scene_objects = []
        for scene_data in scenes_data:
            scene = Scene(
                book_id=book.id,
                order=scene_data.get("order", 0),
                short_summary=scene_data.get("short_summary", "")
            )
            db.add(scene)
            scene_objects.append(scene)
        
        db.commit()
        db.refresh(book)
        
        # Формируем ответ
        scenes_response = [
            SceneResponse(
                order=scene.order,
                short_summary=scene.short_summary or ""
            )
            for scene in scene_objects
        ]
        
        return CreatePlotResponse(
            book_id=str(book.id),  # Преобразуем UUID в строку
            scenes=scenes_response
        )
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании сюжета: {str(e)}")


@router.post("/create_plot", response_model=CreatePlotResponse)
async def create_plot(
    request: CreatePlotRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создает сюжет книги для ребёнка с помощью GPT API.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _create_plot_internal(request, db, user_id)

