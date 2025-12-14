from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class Scene(Base):
    __tablename__ = "scenes"

    id = Column(Integer, primary_key=True, index=True)

    # Исправлено: UUID вместо Integer
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)

    order = Column(Integer, nullable=False)
    short_summary = Column(String, nullable=True)
    text = Column(Text, nullable=True)
    image_prompt = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    # связь с книгой
    book = relationship("Book", back_populates="scenes")
