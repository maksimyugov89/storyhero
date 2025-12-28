from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
import json

from ..db import get_db
from ..models import Child
from ..services.gemini_service import generate_text
from ..core.deps import get_current_user

router = APIRouter(prefix="", tags=["profile"])


class CreateProfileRequest(BaseModel):
    name: str
    age: int
    interests: List[str]
    fears: List[str]
    personality: str
    moral: str


class CreateProfileResponse(BaseModel):
    status: str
    child_id: int
    profile: dict


async def _create_profile_internal(
    request: CreateProfileRequest,
    db: Session,
    user_id: str
) -> CreateProfileResponse:
    """
    Внутренняя функция для создания профиля ребёнка.
    Принимает user_id напрямую, без Depends().
    """
    try:
        # Формируем промпты для GPT
        system_prompt = """Ты - эксперт по детской психологии и созданию персонализированных историй для детей. 
Твоя задача - создать детальный профиль ребёнка на основе анкеты.
Верни результат ТОЛЬКО в формате JSON, без дополнительного текста."""

        user_prompt = f"""Создай детальный профиль для ребёнка на основе следующих данных:

Имя: {request.name}
Возраст: {request.age}
Интересы: {', '.join(request.interests)}
Страхи: {', '.join(request.fears)}
Характер: {request.personality}
Мораль/ценности: {request.moral}

Верни JSON со следующей структурой:
{{
  "name": "{request.name}",
  "age": {request.age},
  "traits": ["список", "черт", "характера"],
  "interests": {json.dumps(request.interests, ensure_ascii=False)},
  "fears": {json.dumps(request.fears, ensure_ascii=False)},
  "moral": "{request.moral}",
  "story_style": "описание стиля историй (например: приключенческие, волшебные, реалистичные)",
  "recommended_theme": "рекомендуемая тема для историй",
  "character_archetype": "архетип персонажа (например: герой, исследователь, защитник)",
  "profile_summary": "краткое резюме профиля ребёнка"
}}"""

        # Вызываем Gemini API
        gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
        
        # Проверяем, что ответ не пустой
        if not gpt_response or not gpt_response.strip():
            raise ValueError("GPT вернул пустой ответ")
        
        # Парсим JSON ответ
        try:
            profile_data = json.loads(gpt_response)
        except json.JSONDecodeError:
            # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
            import re
            json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
            if json_match:
                try:
                    profile_data = json.loads(json_match.group())
                except json.JSONDecodeError:
                    raise ValueError(f"Не удалось распарсить JSON из ответа GPT. Ответ: {gpt_response[:200]}")
            else:
                raise ValueError(f"Не удалось найти JSON в ответе GPT. Ответ: {gpt_response[:200]}")
        
        # Создаем запись в БД
        child = Child(
            name=request.name,
            age=request.age,
            interests=request.interests,
            fears=request.fears,
            personality=request.personality,
            moral=request.moral,
            profile_json=profile_data,
            user_id=user_id  # Сохраняем user_id для приватности
        )
        
        db.add(child)
        db.commit()
        db.refresh(child)
        
        return CreateProfileResponse(
            status="ok",
            child_id=child.id,
            profile=profile_data
        )
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании профиля: {str(e)}")


@router.post("/create_profile", response_model=CreateProfileResponse)
async def create_profile(
    request: CreateProfileRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создает профиль ребёнка с помощью GPT API и сохраняет в БД.
    """
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    return await _create_profile_internal(request, db, user_id)




