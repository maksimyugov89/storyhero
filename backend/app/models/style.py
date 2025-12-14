from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from ..db import Base


class ThemeStyle(Base):
    __tablename__ = "theme_styles"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False, unique=True)
    mode = Column(String, nullable=False)  # "manual" or "auto"
    selected_style = Column(String, nullable=True)  # для manual mode
    auto_style = Column(String, nullable=True)  # для auto mode
    final_style = Column(String, nullable=False)  # итоговый стиль для использования
    created_at = Column(DateTime(timezone=True), server_default=func.now())

