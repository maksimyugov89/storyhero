from pydantic import BaseModel, ConfigDict
from typing import Optional, Any, Dict, List, Union
from uuid import UUID
from datetime import datetime


class BookBase(BaseModel):
    title: str
    description: Optional[str] = None
    genre: Optional[str] = None
    theme: Optional[str] = None
    writing_style: Optional[str] = None
    narrator: Optional[str] = None

    cover_url: Optional[str] = None
    content: Optional[str] = None
    pages: Optional[Union[Dict[str, Any], List[Any]]] = None  # JSONB может быть dict или list
    prompt: Optional[str] = None
    ai_model: Optional[str] = None
    variables_used: Optional[Union[Dict[str, Any], List[Any]]] = None  # JSONB может быть dict или list
    audio_url: Optional[str] = None
    status: str = "draft"  # NOT NULL в базе, всегда строка
    
    # Workflow fields
    final_pdf_url: Optional[str] = None
    images_final: Optional[Union[Dict[str, Any], List[Any]]] = None  # JSONB может быть dict или list
    edit_history: Optional[Union[Dict[str, Any], List[Any]]] = None  # JSONB может быть dict или list
    detail_prompt: Optional[str] = None


class BookCreate(BookBase):
    child_id: int  # INTEGER для совместимости с существующей таблицей children


class BookUpdate(BookBase):
    pass


class BookOut(BookBase):
    id: UUID
    child_id: int  # INTEGER для совместимости с существующей таблицей children
    user_id: Optional[str] = None  # Добавлено: поле из SQLAlchemy модели
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)  # Pydantic v2: для работы с ORM объектами


class SceneOut(BaseModel):
    """
    Модель ответа для сцены книги.
    
    ВАЖНО: Все строковые поля ВСЕГДА имеют дефолтное значение "" (пустая строка),
    чтобы гарантировать null-safety для фронтенда. Ни одно поле не может быть null.
    """
    id: int
    order: int
    title: str = ""  # ВСЕГДА строка, не null
    text: str = ""  # ВСЕГДА строка, не null
    short_summary: str = ""  # ВСЕГДА строка, не null
    image_url: str = ""  # ВСЕГДА строка, не null (URL финального изображения)
    audio_url: str = ""  # ВСЕГДА строка, не null (URL аудио, если есть)
    illustration_prompt: str = ""  # ВСЕГДА строка, не null (промпт для иллюстрации)
    created_at: Optional[str] = None  # ISO datetime string или null

    model_config = ConfigDict(from_attributes=False)  # Не используем from_attributes, т.к. формируем вручную


