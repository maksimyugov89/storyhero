from sqlalchemy import Column, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class SupportMessage(Base):
    """Модель для сообщений пользователей в поддержку"""
    __tablename__ = "support_messages"

    id = Column(UUID(as_uuid=True), primary_key=True, index=True, server_default=func.gen_random_uuid())
    user_id = Column(String, nullable=False, index=True)  # UUID пользователя как строка
    name = Column(String(255), nullable=False)
    email = Column(String(255), nullable=False)
    type = Column(String(50), nullable=False)  # 'suggestion', 'bug', 'question'
    message = Column(Text, nullable=False)
    status = Column(String(50), nullable=False, default="new", index=True)  # 'new', 'answered', 'closed'
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationships
    replies = relationship("SupportMessageReply", back_populates="support_message", cascade="all, delete-orphan")


class SupportMessageReply(Base):
    """Модель для ответов на сообщения поддержки"""
    __tablename__ = "support_message_replies"

    id = Column(UUID(as_uuid=True), primary_key=True, index=True, server_default=func.gen_random_uuid())
    message_id = Column(UUID(as_uuid=True), ForeignKey("support_messages.id", ondelete="CASCADE"), nullable=False, index=True)
    reply_text = Column(Text, nullable=False)
    replied_by = Column(String(255), nullable=True)  # 'telegram', 'admin_user_id', 'user_{user_id}'
    is_read = Column(Boolean, nullable=False, default=False, index=True)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now(), index=True)
    
    # Relationships
    support_message = relationship("SupportMessage", back_populates="replies")

