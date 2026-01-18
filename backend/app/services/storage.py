"""
Модуль storage.py - для работы с локальным хранилищем файлов
"""
import os
import uuid
import logging
from pathlib import Path
from fastapi import HTTPException, UploadFile

# Базовая директория для загрузки файлов
BASE_UPLOAD_DIR = os.getenv(
    "BASE_UPLOAD_DIR",
    "/var/www/storyhero/uploads"
)

# Максимальный размер файла (10MB)
MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB

# Разрешённые MIME типы для изображений
ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

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


def upload_general_file_bytes(file_bytes: bytes, path: str, content_type: str = "application/octet-stream") -> str:
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


async def upload_general_file(file: UploadFile, subfolder: str = "general") -> str:
    """
    Загрузить файл из UploadFile в локальное хранилище.
    Используется для Web и мобильных приложений.
    
    Args:
        file: UploadFile объект из FastAPI
        subfolder: Подпапка для сохранения (по умолчанию "general")
    
    Returns:
        str: Публичный URL файла
    
    Raises:
        HTTPException: Если загрузка не удалась или файл не соответствует требованиям
    """
    try:
        # Проверяем MIME тип
        content_type = file.content_type or "application/octet-stream"
        if content_type not in ALLOWED_IMAGE_TYPES:
            raise HTTPException(
                status_code=400,
                detail=f"Неподдерживаемый формат файла: {content_type}. "
                       f"Разрешены: {', '.join(ALLOWED_IMAGE_TYPES.keys())}"
            )
        
        # Читаем содержимое файла
        contents = await file.read()
        
        # Проверяем размер файла
        file_size = len(contents)
        if file_size > MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"Файл слишком большой: {file_size / (1024*1024):.1f}MB. "
                       f"Максимальный размер: {MAX_FILE_SIZE / (1024*1024):.0f}MB"
            )
        
        if file_size == 0:
            raise HTTPException(
                status_code=400,
                detail="Файл пустой"
            )
        
        # Генерируем уникальное имя файла
        extension = ALLOWED_IMAGE_TYPES.get(content_type, ".bin")
        unique_filename = f"{uuid.uuid4()}{extension}"
        relative_path = f"{subfolder}/{unique_filename}"
        
        # Сохраняем файл
        full_path = Path(BASE_UPLOAD_DIR) / relative_path
        full_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(full_path, "wb") as f:
            f.write(contents)
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        # Убираем порт :8000 из URL для production
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        public_url = f"{base_url}/static/{relative_path}"
        
        logger.info(f"✓ Файл загружен: {public_url} (размер: {file_size / 1024:.1f}KB)")
        
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка при загрузке файла: {e}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке файла: {str(e)}"
        )


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
