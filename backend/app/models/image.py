from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.sql import func
from ..db import Base


class Image(Base):
    __tablename__ = "images"

    id = Column(Integer, primary_key=True, index=True)
    book_id = Column(UUID(as_uuid=True), ForeignKey("books.id", ondelete="CASCADE"), nullable=False)
    scene_order = Column(Integer, nullable=False)
    draft_url = Column(Text, nullable=True)
    final_url = Column(Text, nullable=True)
    style = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

