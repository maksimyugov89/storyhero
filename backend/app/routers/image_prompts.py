"""
Роутер для генерации промптов для изображений через Gemini API.
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
import json
import logging

from ..db import get_db
from ..models import Book, Scene
from ..services.gemini_service import generate_text
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["image_prompts"])


class CreateImagePromptsRequest(BaseModel):
    book_id: str  # UUID как строка


async def _create_image_prompts_internal(
    request: CreateImagePromptsRequest,
    db: Session,
    user_id: str
):
    """
    Внутренняя функция для генерации промптов для изображений.
    Принимает user_id напрямую, без Depends().
    """
    try:
        logger.info(f"🖼️ _create_image_prompts_internal: Начало для book_id={request.book_id}")
        
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
        
        # Получаем полную анкету ребенка для использования в промптах
        from ..models import Child
        child = None
        child_profile = None
        if book.child_id:
            child = db.query(Child).filter(Child.id == book.child_id).first()
            if child:
                # Формируем полный профиль ребенка
                child_profile = {
                    "name": child.name,
                    "age": child.age,
                    "gender": child.gender or "male",  # Пол ребенка для правильной генерации изображений
                    "interests": child.interests or [],
                    "fears": child.fears or [],
                    "personality": child.personality or "",
                    "moral": child.moral or "",
                    "profile_json": child.profile_json or {}
                }
                logger.info(f"📸 Найден ребенок для книги: {child.name}, возраст {child.age} лет, пол: {child.gender or 'male'}, интересы: {child.interests}, характер: {child.personality}")
        
        # Получаем сцены, отсортированные по порядку
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        if not scenes:
            raise HTTPException(status_code=404, detail=f"Сцены для книги с id={request.book_id} не найдены")
        
        # Формируем промпты для Gemini API
        child_age = child_profile['age'] if child_profile else None
        child_gender = child_profile.get('gender', 'male')  # Пол ребенка
        gender_text = "мальчик" if child_gender == "male" else "девочка"
        
        age_instruction = f"КРИТИЧЕСКИ ВАЖНО: В КАЖДОМ промпте ОБЯЗАТЕЛЬНО укажи ТОЧНЫЙ возраст ребенка ({child_age} лет) - персонаж ДОЛЖЕН выглядеть именно как ребенок этого возраста, не старше! Укажи детские пропорции: крупная голова относительно тела, короткие ноги, маленькие руки, пухлые щеки." if child_age else ""
        gender_instruction = f"КРИТИЧЕСКИ ВАЖНО: В КАЖДОМ промпте ОБЯЗАТЕЛЬНО укажи, что главный персонаж - это {gender_text} ({child_age} лет). Персонаж должен быть именно {gender_text}, а не противоположного пола!" if child_age and child_gender else ""
        
        system_prompt = f"""Ты — эксперт по созданию визуальных описаний для детских книг. 
Создавай яркие, детальные промпты для иллюстраций, которые передают настроение и действие сцены.
{age_instruction}
{gender_instruction}
КРИТИЧЕСКИ ВАЖНО: 
1. В промпте обязательно укажи точный возраст ребенка, чтобы персонаж на иллюстрации соответствовал возрасту.
2. В промпте обязательно укажи пол ребенка ({gender_text}), чтобы персонаж был правильного пола.
3. Учитывай интересы, характер и особенности ребенка при описании визуальных элементов.
4. Персонаж должен отражать индивидуальность ребенка из анкеты.
Верни результат ТОЛЬКО в формате JSON, без дополнительного текста."""
        
        scenes_data = [
            {
                "order": scene.order,
                "text": scene.text or scene.short_summary or "",
                "short_summary": scene.short_summary or ""
            }
            for scene in scenes
        ]
        
        # Формируем детальную инструкцию на основе полной анкеты ребенка
        child_instructions = ""
        if child_profile:
            child_instructions = f"""

ПРОФИЛЬ РЕБЕНКА (КРИТИЧЕСКИ ВАЖНО использовать при создании промптов):
{json.dumps(child_profile, ensure_ascii=False, indent=2)}

В каждом промпте для иллюстрации ОБЯЗАТЕЛЬНО учитывай:
1. ВОЗРАСТ И ПОЛ (КРИТИЧЕСКИ ВАЖНО!): Главный персонаж (ребенок) ДОЛЖЕН выглядеть ТОЧНО как {gender_text} {child_profile['age']} лет. 
   - Рост: примерно {round(100 + child_profile['age'] * 5)}-{round(110 + child_profile['age'] * 5)} см
   - Пропорции: голова крупнее относительно тела, короткие ноги, маленькие руки
   - Лицо: детские черты, пухлые щеки, большие глаза
   - Пол: персонаж должен быть именно {gender_text}, а не противоположного пола!
   - В промпте ОБЯЗАТЕЛЬНО укажи: 'a {child_profile['age']}-year-old {gender_text}', '{gender_text} aged {child_profile['age']}', '{gender_text} {child_profile['age']} лет'
   - НИКОГДА не делай персонажа старше или взрослее! Он должен выглядеть именно как {child_profile['age']}-летний {gender_text}!
2. ИМЯ: Главного персонажа зовут {child_profile['name']} - это должно отражаться в визуальном стиле персонажа.
3. ИНТЕРЕСЫ: {', '.join(child_profile['interests']) if child_profile['interests'] else 'не указаны'} - эти интересы могут быть отражены в деталях иллюстрации (одежда, предметы, окружение).
4. ХАРАКТЕР: {child_profile['personality'] if child_profile['personality'] else 'не указан'} - это должно отражаться в выражении лица, позе, жестах персонажа.
5. СТРАХИ: {', '.join(child_profile['fears']) if child_profile['fears'] else 'не указаны'} - учитывай при создании атмосферы сцен, связанных с этими темами.
6. ЦЕННОСТИ/МОРАЛЬ: {child_profile['moral'] if child_profile['moral'] else 'не указаны'} - это должно быть отражено в общем настроении и визуальном стиле иллюстраций.

Это архиважно для создания персонализированной книги, которая точно отражает индивидуальность ребенка!"""
        
        user_prompt = f"""Книга: {book.title}
Тема: {book.theme or 'универсальная'}{child_instructions}

Сцены:
{json.dumps(scenes_data, ensure_ascii=False)}

Создай промпты для иллюстраций каждой сцены. Промпт должен быть детальным, описывать визуальные элементы, настроение, цвета, композицию.
ОБЯЗАТЕЛЬНО учитывай весь профиль ребенка при создании каждого промпта!

ВАЖНО ДЛЯ ОБЛОЖКИ (order=0):
- Обложка должна быть книжной обложкой БЕЗ текста названия (название будет добавлено программно позже)
- Фокус на визуальных элементах: персонаж, фон, атмосфера
- НЕ упоминай название книги в промпте - оно не должно быть частью изображения

Формат JSON:
{{
  "prompts": [
    {{
      "order": 0,
      "prompt": "Book cover illustration. [детальное описание обложки БЕЗ текста названия]"
    }},
    {{
      "order": 1,
      "prompt": "детальное описание иллюстрации для сцены 1"
    }},
    {{
      "order": 2,
      "prompt": "..."
    }}
  ]
}}"""
        
        # Вызываем Gemini API
        logger.info(f"🖼️ _create_image_prompts_internal: Вызов Gemini API для book_id={request.book_id}")
        gpt_response = await generate_text(user_prompt, system_prompt, json_mode=True)
        logger.info(f"🖼️ _create_image_prompts_internal: Gemini API вернул ответ (длина: {len(gpt_response) if gpt_response else 0})")
        
        # Проверяем, что ответ не пустой
        if not gpt_response or not gpt_response.strip():
            logger.error(f"❌ _create_image_prompts_internal: GPT вернул пустой ответ для book_id={request.book_id}")
            raise ValueError("GPT вернул пустой ответ")
        
        # Парсим JSON ответ
        try:
            prompts_data = json.loads(gpt_response)
        except json.JSONDecodeError:
            # Если GPT вернул не чистый JSON, попробуем извлечь JSON из текста
            import re
            json_match = re.search(r'\{.*\}', gpt_response, re.DOTALL)
            if json_match:
                try:
                    prompts_data = json.loads(json_match.group())
                except json.JSONDecodeError:
                    raise ValueError(f"Не удалось распарсить JSON из ответа GPT. Ответ: {gpt_response[:200]}")
            else:
                raise ValueError(f"Не удалось найти JSON в ответе GPT. Ответ: {gpt_response[:200]}")
        
        # Обновляем промпты сцен в БД
        scenes_dict = {scene.order: scene for scene in scenes}
        updated_scenes = []
        missing_prompts = []
        
        # Сначала обновляем промпты, которые вернул Gemini
        for prompt_data in prompts_data.get("prompts", []):
            order = prompt_data.get("order")
            prompt = prompt_data.get("prompt", "").strip()
            
            if order in scenes_dict:
                scene = scenes_dict[order]
                if prompt:  # Только если промпт не пустой
                    scene.image_prompt = prompt
                    updated_scenes.append(scene)
                else:
                    logger.warning(f"⚠️ Пустой промпт для сцены order={order}, book_id={request.book_id}")
                    missing_prompts.append(order)
            else:
                logger.warning(f"⚠️ Промпт для несуществующей сцены order={order}, book_id={request.book_id}")
        
        # Проверяем, что все сцены получили промпты
        scenes_without_prompts = [order for order, scene in scenes_dict.items() if not scene.image_prompt]
        
        if scenes_without_prompts:
            logger.error(f"❌ КРИТИЧНО: {len(scenes_without_prompts)} сцен остались без промптов: orders={scenes_without_prompts}, book_id={request.book_id}")
            
            # Создаем fallback промпты для сцен без промптов
            for order in scenes_without_prompts:
                scene = scenes_dict[order]
                # Создаем базовый промпт на основе текста сцены
                fallback_prompt = f"Illustration for scene {order}: {scene.text[:200] if scene.text else scene.short_summary or 'story scene'}"
                scene.image_prompt = fallback_prompt
                updated_scenes.append(scene)
                logger.info(f"✅ Создан fallback промпт для сцены order={order}")
        
        db.commit()
        logger.info(f"✓ _create_image_prompts_internal: Промпты сохранены в БД для book_id={request.book_id}, обновлено сцен: {len(updated_scenes)}, всего сцен: {len(scenes)}")
        
        logger.info(f"✅ _create_image_prompts_internal: Успешно завершено для book_id={request.book_id}")
        
    except HTTPException:
        raise
    except ValueError as e:
        logger.error(f"❌ _create_image_prompts_internal: ValueError для book_id={request.book_id}: {str(e)}")
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"❌ _create_image_prompts_internal: Exception для book_id={request.book_id}: {str(e)}", exc_info=True)
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Ошибка при создании промптов: {str(e)}")


@router.post("/create_image_prompts")
async def create_image_prompts(
    request: CreateImagePromptsRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует промпты для изображений всех сцен книги с помощью Gemini API.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    return await _create_image_prompts_internal(request, db, user_id)
