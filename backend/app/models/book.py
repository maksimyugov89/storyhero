from sqlalchemy import Column, String, Text, ForeignKey, DateTime, Integer, Boolean
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class Book(Base):
    __tablename__ = "books"

    id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.gen_random_uuid())
    child_id = Column(Integer, ForeignKey("children.id", ondelete="CASCADE"), nullable=False)  # INTEGER для совместимости с существующей таблицей children
    user_id = Column(String, nullable=True)  # UUID из Supabase auth.users (для совместимости со старым кодом)

    title = Column(String, nullable=False)
    description = Column(Text)

    genre = Column(String)
    theme = Column(String)
    writing_style = Column(String)
    narrator = Column(String)

    cover_url = Column(String)

    content = Column(Text)
    pages = Column(JSONB)
    prompt = Column(Text)
    ai_model = Column(String)
    variables_used = Column(JSONB)
    audio_url = Column(String)

    status = Column(String, nullable=False, default="draft")
    
    # Поле оплаты
    is_paid = Column(Boolean, default=False, nullable=False)

    # Workflow fields
    final_pdf_url = Column(Text)
    images_final = Column(JSONB)
    edit_history = Column(JSONB)
    detail_prompt = Column(Text)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    scenes = relationship(
        "Scene",
        back_populates="book",
        cascade="all, delete-orphan"
    )
