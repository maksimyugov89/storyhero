from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
import json

from ..db import get_db
from ..models import Child, Book, Scene
from ..services.deepseek_service import generate_text
from ..core.deps import get_current_user

router = APIRouter(prefix="", tags=["image_prompts"])


class CreateImagePromptsRequest(BaseModel):
    book_id: str  # UUID как строка


class SceneImagePromptResponse(BaseModel):
    order: int
    image_prompt: str


class CreateImagePromptsResponse(BaseModel):
    scenes: List[SceneImagePromptResponse]


async def _create_image_prompts_internal(
    request: CreateImagePromptsRequest,
    db: Session,
    user_id: str
) -> CreateImagePromptsResponse:
    """
    Внутренняя функция для генерации промптов изображений.
    Принимает user_id напрямую, без Depends().
    """
    try:
        # Преобразуем строку book_id в UUID
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(request.book_id) if isinstance(request.book_id, str) else request.book_id
        except (ValueError, TypeError):
            raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {request.book_id}")
        
        # Получаем книгу и сцены из БД
        book = db.query(Book).filter(
            Book.id == book_uuid,
            Book.user_id == user_id
        ).first()
        if not book:
            raise HTTPException(status_code=403, detail="Доступ запрещен: книга не принадлежит вам")
        
        # Получаем профиль ребёнка
        child = db.query(Child).filter(Child.id == book.child_id).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с id={book.child_id} не найден")
        
        # Получаем сцены, отсортированные по порядку
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        if not scenes:
            raise HTTPException(status_code=404, detail=f"Сцены для книги с id={request.book_id} не найдены")
        
        # Подготавливаем данные для промпта
        child_profile = {
            "name": child.name,
            "age": child.age,
            "interests": child.interests or [],
            "fears": child.fears or [],
            "personality": child.personality or "",
            "moral": child.moral or "",
            "profile_json": child.profile_json or {}
        }
        
        # Формируем промпты для каждой сцены
        system_prompt = """Ты создаёшь промты для Stable Diffusion XL. 
Используй единый стиль: мягкая сказочная иллюстрация, яркие цвета, тёплый свет, дружелюбные персонажи."""
        
        updated_scenes = []
        
        for scene in scenes:
            user_prompt = f"""Профиль ребёнка: {json.dumps(child_profile, ensure_ascii=False)}

Сцена: {scene.short_summary or ""}

Формат JSON:
{{
  "scenes": [
    {{
      "order": {scene.order},
      "image_prompt": "..."
    }}
  ]
}}"""
            
            # Вызываем DeepSeek API для каждой сцены
            gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
            
            # Проверяем, что ответ не пустой
            if not gpt_response or not gpt_response.strip():
                raise ValueError(f"GPT вернул пустой ответ для сцены {scene.order}")
            
            # Парсим JSON ответ
            try:
                prompt_data = json.loads(gpt_response)
            except json.JSONDecodeError:
                # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
                import re
                json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
                if json_match:
                    try:
                        prompt_data = json.loads(json_match.group())
                    except json.JSONDecodeError:
                        raise ValueError(f"Не удалось распарсить JSON из ответа GPT для сцены {scene.order}. Ответ: {gpt_response[:200]}")
                else:
                    raise ValueError(f"Не удалось найти JSON в ответе GPT для сцены {scene.order}. Ответ: {gpt_response[:200]}")
            
            # Обновляем промпт сцены в БД
            scenes_data = prompt_data.get("scenes", [])
            for scene_data in scenes_data:
                if scene_data.get("order") == scene.order:
                    scene.image_prompt = scene_data.get("image_prompt", "")
                    updated_scenes.append(scene)
                    break
        
        db.commit()
        
        # Обновляем объекты в сессии
        for scene in updated_scenes:
            db.refresh(scene)
        
        # Формируем ответ
        scenes_response = [
            SceneImagePromptResponse(
                order=scene.order,
                image_prompt=scene.image_prompt or ""
            )
            for scene in updated_scenes
        ]
        
        return CreateImagePromptsResponse(scenes=scenes_response)
        
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании промптов: {str(e)}")


@router.post("/create_image_prompts", response_model=CreateImagePromptsResponse)
async def create_image_prompts(
    request: CreateImagePromptsRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует промпты для изображений для всех сцен книги с помощью GPT API.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _create_image_prompts_internal(request, db, user_id)

