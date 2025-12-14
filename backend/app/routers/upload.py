"""
Роутер для загрузки файлов (локальное хранилище)
"""
import logging
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel

from ..services.local_file_service import upload_general_file
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="", tags=["upload"])


class UploadResponse(BaseModel):
    """Ответ при успешной загрузке файла"""
    url: str
    message: str = "Файл успешно загружен"


@router.post("/upload", response_model=UploadResponse)
async def upload_file_endpoint(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """
    Загрузить файл на локальный сервер.
    
    Принимает файл через multipart/form-data.
    Сохраняет файл в /var/www/storyhero/uploads/general/
    Возвращает публичный URL загруженного файла.
    
    Требования:
    - Формат: JPEG, PNG, WebP
    - Максимальный размер: 10MB
    - Требуется авторизация (Bearer token)
    """
    try:
        logger.info(f"Запрос на загрузку файла '{file.filename}' от пользователя {current_user.get('id', 'unknown')}")
        
        # Используем локальный сервис загрузки
        public_url = await upload_general_file(file)
        
        return UploadResponse(url=public_url)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Непредвиденная ошибка в /upload: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке файла: {str(e)}"
        )


@router.post("/children/photos", response_model=UploadResponse)
async def upload_child_photo_endpoint(
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    """
    Загрузить фотографию ребёнка на локальный сервер (общий эндпоинт).
    
    Алиас для /upload, специально для фотографий детей.
    Для загрузки фото конкретного ребёнка используйте POST /children/{child_id}/photos
    
    Принимает файл через multipart/form-data.
    Возвращает публичный URL загруженного файла.
    
    Требования:
    - Формат: JPEG, PNG, WebP
    - Максимальный размер: 10MB
    - Требуется авторизация (Bearer token)
    """
    try:
        logger.info(f"Запрос на загрузку фото ребёнка '{file.filename}' от пользователя {current_user.get('id', 'unknown')}")
        
        # Используем локальный сервис загрузки (общий эндпоинт)
        public_url = await upload_general_file(file)
        
        return UploadResponse(url=public_url)
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Непредвиденная ошибка в /children/photos: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке фотографии ребёнка: {str(e)}"
        )
