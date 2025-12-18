"""
Модель для хранения версий изображений
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class ImageVersion(Base):
    """
    Версия изображения для сцены.
    Позволяет хранить до 3 версий изображения для каждой сцены.
    """
    __tablename__ = "image_versions"

    id = Column(Integer, primary_key=True, index=True)
    
    # Связь с изображением и сценой
    image_id = Column(Integer, ForeignKey("images.id", ondelete="CASCADE"), nullable=False)
    scene_id = Column(Integer, ForeignKey("scenes.id", ondelete="CASCADE"), nullable=False)  # ID сцены
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    scene_order = Column(Integer, nullable=False)  # Для быстрого поиска
    
    # Версия изображения
    version_number = Column(Integer, nullable=False)  # 0 = оригинал, 1-3 = редактирования
    image_url = Column(Text, nullable=False)  # URL изображения
    
    # Метаданные редактирования
    edit_instruction = Column(Text, nullable=True)  # Описание того, что нужно изменить
    is_selected = Column(Boolean, default=False, nullable=False)  # Выбрано ли это изображение пользователем
    is_original = Column(Boolean, default=False, nullable=False)  # Является ли это оригинальным изображением
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Индексы для быстрого поиска
    __table_args__ = (
        {"comment": "Версии изображений для сцен. Максимум 3 версии на изображение."}
    )

