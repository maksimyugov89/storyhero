"""
Модель для хранения версий текста сцен
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class TextVersion(Base):
    """
    Версия текста для сцены.
    Позволяет хранить до 5 версий текста для каждой сцены.
    """
    __tablename__ = "text_versions"

    id = Column(Integer, primary_key=True, index=True)
    
    # Связь со сценой
    scene_id = Column(Integer, ForeignKey("scenes.id", ondelete="CASCADE"), nullable=False)
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    scene_order = Column(Integer, nullable=False)  # Для быстрого поиска
    
    # Версия текста
    version_number = Column(Integer, nullable=False)  # 0 = оригинал, 1-5 = редактирования
    text = Column(Text, nullable=False)
    
    # Метаданные редактирования
    edit_instruction = Column(Text, nullable=True)  # Инструкция пользователя для редактирования
    is_selected = Column(Boolean, default=False, nullable=False)  # Выбрана ли эта версия пользователем
    is_original = Column(Boolean, default=False, nullable=False)  # Является ли это оригинальной версией
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Индексы для быстрого поиска
    __table_args__ = (
        {"comment": "Версии текста для сцен. Максимум 5 версий на сцену."}
    )

