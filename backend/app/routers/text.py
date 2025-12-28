from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List
import json

from ..db import get_db
from ..models import Child, Book, Scene
from ..services.gemini_service import generate_text
from ..core.deps import get_current_user

router = APIRouter(prefix="", tags=["text"])


class CreateTextRequest(BaseModel):
    book_id: str  # UUID как строка


class SceneTextResponse(BaseModel):
    order: int
    text: str


class CreateTextResponse(BaseModel):
    scenes: List[SceneTextResponse]


async def _create_text_internal(
    request: CreateTextRequest,
    db: Session,
    user_id: str
) -> CreateTextResponse:
    """
    Внутренняя функция для генерации текста.
    Принимает user_id напрямую, без Depends().
    """
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"📝 _create_text_internal: Начало для book_id={request.book_id}")
        # Преобразуем строку book_id в UUID
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(request.book_id)
        except ValueError:
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
            "gender": child.gender or "male",  # Пол ребенка для правильной генерации текста
            "interests": child.interests or [],
            "fears": child.fears or [],
            "personality": child.personality or "",
            "moral": child.moral or "",
            "profile_json": child.profile_json or {}
        }
        
        scenes_plan = [
            {
                "order": scene.order,
                "short_summary": scene.short_summary or ""
            }
            for scene in scenes
        ]
        
        # Формируем промпты для GPT
        system_prompt = """Ты — детский писатель. Пиши текст на 1–2 абзаца для каждой сцены, мягко, доброжелательно, литературно."""
        
        user_prompt = f"""Профиль ребёнка: {json.dumps(child_profile, ensure_ascii=False)}

План сцен: {json.dumps(scenes_plan, ensure_ascii=False)}

Напиши текст для каждой сцены.

Формат JSON:
{{
  "scenes": [
    {{
      "order": 1,
      "text": "..."
    }}
  ]
}}"""
        
        # Вызываем Gemini API
        logger.info(f"📝 _create_text_internal: Вызов Gemini API для book_id={request.book_id}")
        gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
        logger.info(f"📝 _create_text_internal: Gemini API вернул ответ (длина: {len(gpt_response) if gpt_response else 0})")
        
        # Проверяем, что ответ не пустой
        if not gpt_response or not gpt_response.strip():
            logger.error(f"❌ _create_text_internal: GPT вернул пустой ответ для book_id={request.book_id}")
            raise ValueError("GPT вернул пустой ответ")
        
        # Парсим JSON ответ
        try:
            text_data = json.loads(gpt_response)
        except json.JSONDecodeError:
            # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
            import re
            json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
            if json_match:
                try:
                    text_data = json.loads(json_match.group())
                except json.JSONDecodeError:
                    raise ValueError(f"Не удалось распарсить JSON из ответа GPT. Ответ: {gpt_response[:200]}")
            else:
                raise ValueError(f"Не удалось найти JSON в ответе GPT. Ответ: {gpt_response[:200]}")
        
        # Обновляем тексты сцен в БД
        scenes_dict = {scene.order: scene for scene in scenes}
        updated_scenes = []
        
        for scene_data in text_data.get("scenes", []):
            order = scene_data.get("order")
            text = scene_data.get("text", "")
            
            if order in scenes_dict:
                scene = scenes_dict[order]
                scene.text = text
                updated_scenes.append(scene)
        
        db.commit()
        logger.info(f"✓ _create_text_internal: Тексты сохранены в БД для book_id={request.book_id}, обновлено сцен: {len(updated_scenes)}")
        
        # Обновляем объекты в сессии
        for scene in updated_scenes:
            db.refresh(scene)
        
        # Формируем ответ
        scenes_response = [
            SceneTextResponse(
                order=scene.order,
                text=scene.text or ""
            )
            for scene in updated_scenes
        ]
        
        logger.info(f"✅ _create_text_internal: Успешно завершено для book_id={request.book_id}")
        return CreateTextResponse(scenes=scenes_response)
        
    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"❌ _create_text_internal: ValueError для book_id={request.book_id}: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"❌ _create_text_internal: Exception для book_id={request.book_id}: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании текста: {str(e)}")


@router.post("/create_text", response_model=CreateTextResponse)
async def create_text(
    request: CreateTextRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует текст для всех сцен книги с помощью GPT API.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _create_text_internal(request, db, user_id)

