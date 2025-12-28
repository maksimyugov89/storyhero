"""
Модуль storage.py - для работы с локальным хранилищем файлов
"""
import os
import logging
from pathlib import Path
from fastapi import HTTPException

# Базовая директория для загрузки файлов
BASE_UPLOAD_DIR = os.getenv(
    "BASE_UPLOAD_DIR",
    "/var/www/storyhero/uploads"
)

logger = logging.getLogger(__name__)


def upload_image(file_bytes: bytes, path: str, content_type: str = "image/jpeg") -> str:
    """
    Загрузить изображение в локальное хранилище
    
    Args:
        file_bytes: Байты изображения
        path: Относительный путь для сохранения (например, "final/uuid.jpg" или "drafts/uuid.jpg")
        content_type: MIME тип файла (по умолчанию image/jpeg)
    
    Returns:
        str: Публичный URL изображения
    
    Raises:
        HTTPException: Если загрузка не удалась
    """
    try:
        full_path = Path(BASE_UPLOAD_DIR) / path
        full_path.parent.mkdir(parents=True, exist_ok=True)

        with open(full_path, "wb") as f:
            f.write(file_bytes)

        return f"/uploads/{path}"

    except Exception as e:
        logger.error(f"✗ Ошибка при сохранении файла: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))


def upload_general_file(file_bytes: bytes, path: str, content_type: str = "application/octet-stream") -> str:
    """
    Загрузить файл в локальное хранилище (универсальная функция для любых файлов)
    
    Args:
        file_bytes: Байты файла
        path: Относительный путь для сохранения
        content_type: MIME тип файла
    
    Returns:
        str: Публичный URL файла
    
    Raises:
        HTTPException: Если загрузка не удалась
    """
    return upload_image(file_bytes, path, content_type)


def get_server_base_url() -> str:
    """
    Получить базовый URL сервера для формирования полных URL файлов
    
    Returns:
        str: Базовый URL (например, "https://storyhero.ru" или "http://localhost:8000")
    """
    import os
    base_url = os.getenv("SERVER_BASE_URL", "http://localhost:8000")
    # Убираем слэш в конце, если есть
    return base_url.rstrip("/")
