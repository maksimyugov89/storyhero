"""
Модель для хранения face profile ребёнка.
Face profile содержит embedding лица и reference изображение.
"""
from sqlalchemy import Column, Integer, String, LargeBinary, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from ..db import Base


class ChildFaceProfile(Base):
    __tablename__ = "child_face_profiles"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id", ondelete="CASCADE"), nullable=False, unique=True, index=True)
    
    # Embedding лица (сериализованный numpy array float32)
    embedding = Column(LargeBinary, nullable=False)
    
    # Путь к reference изображению (относительно BASE_UPLOAD_DIR)
    reference_image_path = Column(String, nullable=False)
    
    # Метаданные
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    
    # Relationship с Child
    child = relationship("Child", backref="face_profile")

