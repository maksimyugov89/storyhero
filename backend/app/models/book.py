from sqlalchemy import Column, String, Integer, Text, DateTime, ForeignKey, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class Book(Base):
    __tablename__ = "books"

    id = Column(UUID(as_uuid=True), primary_key=True, index=True, server_default=func.gen_random_uuid())
    child_id = Column(Integer, ForeignKey("children.id", ondelete="CASCADE"), nullable=False)
    user_id = Column(String, nullable=True)
    
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    genre = Column(String, nullable=True)
    theme = Column(String, nullable=True)
    writing_style = Column(String, nullable=True)
    narrator = Column(String, nullable=True)
    
    cover_url = Column(Text, nullable=True)
    content = Column(Text, nullable=True)
    pages = Column(JSONB, nullable=True)
    prompt = Column(Text, nullable=True)
    ai_model = Column(String, nullable=True)
    variables_used = Column(JSONB, nullable=True)
    audio_url = Column(Text, nullable=True)
    
    status = Column(String, nullable=False, default="draft")
    
    # Workflow fields
    final_pdf_url = Column(Text, nullable=True)
    images_final = Column(JSONB, nullable=True)
    edit_history = Column(JSONB, nullable=True)
    detail_prompt = Column(Text, nullable=True)
    is_paid = Column(String, nullable=True, default="false")  # "true" или "false" как строка для совместимости
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    scenes = relationship("Scene", back_populates="book", cascade="all, delete-orphan")
