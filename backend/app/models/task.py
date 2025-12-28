"""
Модель задачи генерации книги
"""
from sqlalchemy import Column, String, Text, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from ..db import Base


class Task(Base):
    __tablename__ = "tasks"
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid())
    user_id = Column(String, nullable=False)  # UUID пользователя
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="SET NULL"), nullable=True)  # ID книги, если создана
    
    # Статус задачи
    status = Column(String, nullable=False, default="pending")  # pending, running, success, error
    
    # Метаданные задачи
    meta = Column(JSONB, nullable=True)  # Метаданные для проверки дубликатов
    
    # Прогресс задачи
    progress = Column(JSONB, nullable=True)  # Прогресс генерации
    
    # Результат и ошибки
    result = Column(JSONB, nullable=True)  # Результат выполнения
    error = Column(Text, nullable=True)  # Сообщение об ошибке
    
    # Временные метки
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

