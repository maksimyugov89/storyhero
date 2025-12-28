"""
Pydantic схемы для face profile API.
"""
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime


class CreateFaceProfileRequest(BaseModel):
    """Запрос на создание face profile."""
    photo_paths: List[str]  # Список путей/URL к фотографиям ребёнка


class FaceProfileResponse(BaseModel):
    """Ответ с информацией о face profile."""
    child_id: int
    reference_image_url: str
    embedding_saved: bool
    valid_faces: int
    used_faces: int
    threshold: float = 0.60
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class FaceProfileStatusResponse(BaseModel):
    """Статус face profile."""
    exists: bool
    reference_image_url: Optional[str] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ImageGenerationWithFaceResponse(BaseModel):
    """Ответ при генерации изображения с использованием face profile."""
    image_url: str
    face_similarity: float
    face_verified: bool
    attempts: int
    best_similarity: Optional[float] = None

