from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Literal, Optional
import json

from ..db import get_db
from ..models import Book, Child, Scene, ThemeStyle
from ..services.deepseek_service import generate_text
from ..core.deps import get_current_user
from ..config.styles import ALL_STYLES, normalize_style, is_style_known

router = APIRouter(prefix="", tags=["style"])


class SelectStyleRequest(BaseModel):
    book_id: str  # UUID как строка
    mode: Literal["manual", "auto"]
    style: Optional[str] = None  # для manual mode


class SelectStyleResponse(BaseModel):
    final_style: str


async def _select_style_internal(
    data: SelectStyleRequest,
    db: Session,
    user_id: str
) -> SelectStyleResponse:
    """
    Внутренняя функция для выбора стиля.
    Принимает user_id напрямую, без Depends().
    """
    try:
        # Преобразуем строку book_id в UUID
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(data.book_id)
        except ValueError:
            raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
        
        # Проверяем, что книга существует и принадлежит пользователю
        book = db.query(Book).filter(
            Book.id == book_uuid,
            Book.user_id == user_id
        ).first()
        if not book:
            raise HTTPException(status_code=403, detail="Доступ запрещен: книга не принадлежит вам")
        
        if data.mode == "manual":
            if not data.style:
                raise HTTPException(status_code=400, detail="Для manual mode необходимо указать style")
            
            # Сохраняем ручной стиль
            theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
            
            if theme_style:
                theme_style.mode = "manual"
                theme_style.selected_style = data.style
                theme_style.final_style = data.style
            else:
                theme_style = ThemeStyle(
                    book_id=book_uuid,
                    mode="manual",
                    selected_style=data.style,
                    final_style=data.style
                )
                db.add(theme_style)
            
            db.commit()
            db.refresh(theme_style)
            
            return SelectStyleResponse(final_style=theme_style.final_style)
        
        elif data.mode == "auto":
            # Получаем профиль ребёнка
            child = db.query(Child).filter(Child.id == book.child_id).first()
            if not child:
                raise HTTPException(status_code=404, detail=f"Ребёнок с id={book.child_id} не найден")
            
            # Получаем сцены
            scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
            
            # Формируем данные для LLM
            child_profile = {
                "name": child.name,
                "age": child.age,
                "interests": child.interests or [],
                "fears": child.fears or [],
                "personality": child.personality or "",
                "moral": child.moral or "",
                "profile_json": child.profile_json or {}
            }
            
            scenes_data = [
                {
                    "order": scene.order,
                    "short_summary": scene.short_summary or "",
                    "text": scene.text or ""
                }
                for scene in scenes[:5]  # Берем первые 5 сцен для контекста
            ]
            
            # Формируем промпт для LLM
            system_prompt = """Ты — эксперт по художественным стилям. Подбери уникальный визуальный стиль для детской книги. 
Формат ответа строго JSON, без дополнительного текста: { "auto_style": "название стиля" }

Доступные стили: classic, cartoon, fairytale, watercolor, pencil,
disney, pixar, ghibli, dreamworks, oil_painting, impressionism, pastel, gouache,
digital_art, fantasy, adventure, space, underwater, forest, winter, cute, funny,
educational, retro, pop_art.
Выбери один стиль из списка, который лучше всего подходит ребёнку и сюжету."""
            
            # Получаем moral из variables_used (где сохранен plot_data) или из child
            plot_moral = ""
            if book.variables_used and isinstance(book.variables_used, dict):
                plot_moral = book.variables_used.get("moral", "")
            if not plot_moral:
                plot_moral = child.moral or ""
            
            user_prompt = f"""Профиль ребёнка: {json.dumps(child_profile, ensure_ascii=False)}

Сюжет книги:
Название: {book.title}
Тема: {book.theme or ""}
Мораль: {plot_moral}

Сцены:
{json.dumps(scenes_data, ensure_ascii=False)}

Подбери визуальный стиль для иллюстраций этой книги."""
            
            # Вызываем DeepSeek API
            gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
            
            # Проверяем, что ответ не пустой
            if not gpt_response or not gpt_response.strip():
                raise ValueError("GPT вернул пустой ответ")
            
            # Парсим JSON ответ
            try:
                style_data = json.loads(gpt_response)
            except json.JSONDecodeError:
                # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
                import re
                json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
                if json_match:
                    try:
                        style_data = json.loads(json_match.group())
                    except json.JSONDecodeError:
                        raise ValueError(f"Не удалось распарсить JSON из ответа GPT. Ответ: {gpt_response[:200]}")
                else:
                    raise ValueError(f"Не удалось найти JSON в ответе GPT. Ответ: {gpt_response[:200]}")
            
            auto_style_raw = style_data.get("auto_style", "classic")
            auto_style = normalize_style(auto_style_raw)
            if not is_style_known(auto_style):
                auto_style = "classic"
            
            # Сохраняем автоматический стиль
            theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
            
            if theme_style:
                theme_style.mode = "auto"
                theme_style.auto_style = auto_style
                theme_style.final_style = auto_style
            else:
                theme_style = ThemeStyle(
                    book_id=book_uuid,
                    mode="auto",
                    auto_style=auto_style,
                    final_style=auto_style
                )
                db.add(theme_style)
            
            db.commit()
            db.refresh(theme_style)
            
            return SelectStyleResponse(final_style=theme_style.final_style)
        
        else:
            raise HTTPException(status_code=400, detail="mode должен быть 'manual' или 'auto'")
            
    except HTTPException:
        raise
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при выборе стиля: {str(e)}")


@router.post("/select_style", response_model=SelectStyleResponse)
async def select_style(
    data: SelectStyleRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Выбрать стиль для книги (ручной или автоматический)
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _select_style_internal(data, db, user_id)

