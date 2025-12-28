"""
Модель заказа печатной книги
"""
from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class PrintOrder(Base):
    __tablename__ = "print_orders"
    
    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid())
    user_id = Column(String, nullable=False)  # UUID пользователя
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    book_title = Column(String, nullable=False)
    
    # Параметры заказа
    size = Column(String, nullable=False)  # "A5 (Маленькая)", "B5 (Средняя)", "A4 (Большая)"
    pages = Column(Integer, nullable=False)  # 10 или 20
    binding = Column(String, nullable=False)  # "Мягкий переплёт", "Твёрдый переплёт"
    packaging = Column(String, nullable=False)  # "Простая упаковка", "Подарочная упаковка"
    total_price = Column(Integer, nullable=False)  # Цена в рублях
    
    # Данные клиента
    customer_name = Column(String, nullable=False)
    customer_phone = Column(String, nullable=False)
    customer_address = Column(Text, nullable=False)
    comment = Column(Text, nullable=True)
    
    # Статус: pending, confirmed, processing, shipped, delivered
    status = Column(String, default="pending", nullable=False)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Связь с книгой
    # ВАЖНО: Используем passive_deletes=True, чтобы SQLAlchemy не пытался обновлять book_id при удалении книги
    # Вместо этого заказы удаляются через raw SQL перед удалением книги
    book = relationship("Book", backref="print_orders", passive_deletes=True)

