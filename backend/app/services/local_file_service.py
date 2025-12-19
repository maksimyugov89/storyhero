"""
Сервис для локального хранения файлов
"""
import os
import uuid
import logging
from pathlib import Path
from fastapi import UploadFile, HTTPException
from typing import Optional

logger = logging.getLogger(__name__)

# Базовый путь для хранения файлов
BASE_UPLOAD_DIR = "/var/www/storyhero/uploads"

# Максимальный размер файла: 10MB
MAX_FILE_SIZE = 10 * 1024 * 1024

# Разрешенные форматы
ALLOWED_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_MIME_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp"
}


def get_file_extension(filename: str) -> str:
    """Получить расширение файла"""
    return Path(filename).suffix.lower()


def validate_file(file: UploadFile) -> None:
    """
    Валидация загружаемого файла
    
    Raises:
        HTTPException: Если файл не соответствует требованиям
    """
    if not file.filename:
        raise HTTPException(
            status_code=400,
            detail="Имя файла не указано"
        )
    
    # Проверка расширения
    extension = get_file_extension(file.filename)
    if extension not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Неподдерживаемый формат файла. Разрешены: {', '.join(ALLOWED_EXTENSIONS)}"
        )
    
    # Проверка MIME типа
    if file.content_type and file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Неподдерживаемый тип файла: {file.content_type}. Разрешены: {', '.join(ALLOWED_MIME_TYPES)}"
        )


def ensure_directory_exists(directory_path: str) -> None:
    """
    Создать директорию рекурсивно, если её нет
    
    Args:
        directory_path: Путь к директории
    """
    try:
        Path(directory_path).mkdir(parents=True, exist_ok=True)
        logger.debug(f"Директория создана/проверена: {directory_path}")
    except Exception as e:
        logger.error(f"✗ Ошибка при создании директории {directory_path}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось создать директорию для сохранения файла: {str(e)}"
        )


def get_server_base_url() -> str:
    """
    Получить базовый URL сервера для формирования публичных URL
    
    Returns:
        str: Базовый URL (например, "https://storyhero.ru")
    """
    # Явный публичный URL имеет приоритет (например, https://storyhero.ru)
    public_base = os.getenv("PUBLIC_BASE_URL")
    if public_base:
        return public_base.rstrip("/")

    # Собираем из протокола/хоста/порта
    server_host = os.getenv("SERVER_HOST", "localhost")
    server_port = os.getenv("SERVER_PORT", "")
    server_protocol = os.getenv("SERVER_PROTOCOL", "https")

    # ВАЖНО: Для production через nginx порт не нужен в URL
    # Если это production домен (не localhost), всегда убираем порт
    if server_host not in ("localhost", "127.0.0.1", "0.0.0.0"):
        # Production окружение - не добавляем порт к URL (nginx проксирует)
        return f"{server_protocol}://{server_host}"
    
    # Для localhost/development - добавляем порт если он нестандартный
    # Если порт стандартный — не добавляем
    if (server_protocol == "https" and server_port in ("443", "", None)) or (
        server_protocol == "http" and server_port in ("80", "", None)
    ):
        return f"{server_protocol}://{server_host}"

    # Для development с нестандартным портом - добавляем порт
    return f"{server_protocol}://{server_host}:{server_port}"


async def save_file_to_disk(
    file: UploadFile,
    storage_path: str,
    max_size: int = MAX_FILE_SIZE
) -> str:
    """
    Сохранить файл на диск
    
    Args:
        file: UploadFile объект
        storage_path: Полный абсолютный путь для сохранения файла
        max_size: Максимальный размер файла в байтах
    
    Returns:
        str: Полный путь к сохраненному файлу
    """
    # Читаем содержимое файла
    file_bytes = await file.read()
    
    # Проверка размера
    if len(file_bytes) > max_size:
        raise HTTPException(
            status_code=400,
            detail=f"Файл слишком большой. Максимальный размер: {max_size // (1024*1024)}MB"
        )
    
    # Проверяем, что файл не пустой
    if len(file_bytes) == 0:
        raise HTTPException(
            status_code=400,
            detail="Передан пустой файл"
        )
    
    # Создаём директорию, если её нет
    directory = os.path.dirname(storage_path)
    ensure_directory_exists(directory)
    
    # Сохраняем файл
    try:
        with open(storage_path, "wb") as f:
            f.write(file_bytes)
        logger.info(f"✓ Файл сохранён: {storage_path}")
        return storage_path
    except Exception as e:
        logger.error(f"✗ Ошибка при сохранении файла {storage_path}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось сохранить файл на диск: {str(e)}"
        )


async def upload_general_file(
    file: UploadFile,
    max_size: int = MAX_FILE_SIZE
) -> str:
    """
    Загрузить общий файл (не привязанный к ребёнку)
    
    Args:
        file: UploadFile объект
        max_size: Максимальный размер файла
    
    Returns:
        str: Публичный URL файла
    """
    try:
        # Валидация файла
        validate_file(file)
        
        # Генерируем уникальное имя файла
        file_extension = get_file_extension(file.filename)
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        
        # Формируем полный путь для сохранения
        storage_dir = os.path.join(BASE_UPLOAD_DIR, "general")
        storage_path = os.path.join(storage_dir, unique_filename)
        
        logger.info(f"Загрузка общего файла '{file.filename}' -> '{storage_path}'...")
        
        # Сохраняем файл
        await save_file_to_disk(file, storage_path, max_size)
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        public_url = f"{base_url}/static/general/{unique_filename}"
        
        logger.info(f"✓ Файл доступен по URL: {public_url}")
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Непредвиденная ошибка при загрузке общего файла: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке файла: {str(e)}"
        )


async def upload_child_photo(
    file: UploadFile,
    child_id: str,
    max_size: int = MAX_FILE_SIZE
) -> str:
    """
    Загрузить фотографию ребёнка
    
    Args:
        file: UploadFile объект
        child_id: UUID ребёнка
        max_size: Максимальный размер файла
    
    Returns:
        str: Публичный URL файла
    """
    try:
        # Валидация файла
        validate_file(file)
        
        # Генерируем уникальное имя файла
        file_extension = get_file_extension(file.filename)
        unique_filename = f"{uuid.uuid4()}{file_extension}"
        
        # Формируем полный путь для сохранения
        # /var/www/storyhero/uploads/children/<child_id>/<filename>
        storage_dir = os.path.join(BASE_UPLOAD_DIR, "children", child_id)
        storage_path = os.path.join(storage_dir, unique_filename)
        
        logger.info(f"Загрузка фото ребёнка {child_id} '{file.filename}' -> '{storage_path}'...")
        
        # Сохраняем файл
        await save_file_to_disk(file, storage_path, max_size)
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        public_url = f"{base_url}/static/children/{child_id}/{unique_filename}"
        
        logger.info(f"✓ Фото ребёнка доступно по URL: {public_url}")
        return public_url
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Непредвиденная ошибка при загрузке фото ребёнка: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке фотографии ребёнка: {str(e)}"
        )


def upload_image_bytes(
    file_bytes: bytes,
    relative_path: str,
    content_type: str = "image/jpeg"
) -> str:
    """
    Сохранить изображение из байтов в локальное хранилище
    
    Используется для сохранения изображений, сгенерированных API (например, OpenRouter).
    
    Args:
        file_bytes: Байты изображения
        relative_path: Относительный путь внутри uploads (например, "final/uuid.jpg" или "drafts/uuid.jpg")
        content_type: MIME тип файла
    
    Returns:
        str: Публичный URL сохраненного изображения
    """
    try:
        # Формируем полный путь для сохранения
        storage_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
        
        # Создаём директорию, если её нет
        directory = os.path.dirname(storage_path)
        ensure_directory_exists(directory)
        
        # Сохраняем файл
        with open(storage_path, "wb") as f:
            f.write(file_bytes)
        
        logger.info(f"✓ Изображение сохранено: {storage_path}")
        
        # Формируем публичный URL
        base_url = get_server_base_url()
        public_url = f"{base_url}/static/{relative_path}"
        
        return public_url
        
    except Exception as e:
        logger.error(f"✗ Ошибка при сохранении изображения: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось сохранить изображение: {str(e)}"
        )
