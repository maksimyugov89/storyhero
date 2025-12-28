"""
Сервис для безопасной загрузки и валидации изображений.
Гарантирует, что загруженные байты - это реальное изображение, а не HTML/ошибка/заглушка.
"""
import logging
import requests
from typing import Optional
from io import BytesIO
from PIL import Image

logger = logging.getLogger(__name__)


class ImageFetchError(Exception):
    """Исключение при ошибке загрузки/валидации изображения."""
    pass


def validate_image_bytes(image_bytes: bytes) -> bool:
    """
    Проверяет, что байты являются валидным изображением.
    
    Args:
        image_bytes: Байты для проверки
    
    Returns:
        True если это валидное изображение, False иначе
    """
    if not image_bytes or len(image_bytes) < 10:
        return False
    
    # Проверка сигнатур форматов
    # JPEG: начинается с FF D8
    if image_bytes.startswith(b"\xff\xd8"):
        return True
    
    # PNG: начинается с 89 50 4E 47
    if image_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return True
    
    # WEBP: начинается с RIFF и содержит WEBP
    if image_bytes.startswith(b"RIFF") and b"WEBP" in image_bytes[:20]:
        return True
    
    # Дополнительная проверка через PIL
    try:
        img = Image.open(BytesIO(image_bytes))
        img.verify()
        return True
    except Exception:
        pass
    
    return False


def fetch_image_bytes(url: str, timeout: int = 20, retries: int = 3) -> bytes:
    """
    Загружает изображение по URL с валидацией и ретраями.
    
    Args:
        url: URL изображения
        timeout: Таймаут запроса в секундах
        retries: Количество попыток при ошибке
    
    Returns:
        bytes: Байты валидного изображения
    
    Raises:
        ImageFetchError: Если изображение не удалось загрузить или оно невалидно
    """
    if not url:
        raise ImageFetchError("URL изображения не указан")
    
    last_error = None
    
    for attempt in range(1, retries + 1):
        try:
            logger.debug(f"🔄 Попытка {attempt}/{retries} загрузки изображения: {url[:100]}...")
            
            response = requests.get(url, timeout=timeout, stream=True)
            
            # Проверка статус-кода
            if response.status_code != 200:
                error_msg = f"HTTP {response.status_code} для {url[:100]}..."
                logger.warning(f"⚠️ {error_msg}")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            # Проверка Content-Type
            content_type = response.headers.get("Content-Type", "").lower()
            if content_type and not content_type.startswith("image/"):
                error_msg = f"Неверный Content-Type: {content_type} (ожидается image/*)"
                logger.warning(f"⚠️ {error_msg} для {url[:100]}...")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            # Загружаем байты
            image_bytes = response.content
            
            # Проверка размера (минимум 100 байт)
            if len(image_bytes) < 100:
                error_msg = f"Изображение слишком маленькое: {len(image_bytes)} байт"
                logger.warning(f"⚠️ {error_msg}")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            # Проверка на HTML/текст (заглушки типа "Visual style: pixar...")
            if image_bytes.startswith(b"<!DOCTYPE") or image_bytes.startswith(b"<html"):
                error_msg = "Получен HTML вместо изображения (возможно, заглушка/ошибка)"
                logger.error(f"❌ {error_msg} для {url[:100]}...")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            # Проверка на текстовые заглушки
            text_start = image_bytes[:200].decode("utf-8", errors="ignore").lower()
            if "visual style" in text_start or "important" in text_start or "prompt" in text_start:
                error_msg = "Обнаружен текст-заглушка вместо изображения"
                logger.error(f"❌ {error_msg} для {url[:100]}...")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            # Валидация байтов изображения
            if not validate_image_bytes(image_bytes):
                error_msg = "Байты не являются валидным изображением (неверная сигнатура)"
                logger.error(f"❌ {error_msg} для {url[:100]}...")
                last_error = error_msg
                if attempt < retries:
                    continue
                raise ImageFetchError(error_msg)
            
            logger.info(f"✅ Изображение успешно загружено и валидировано: {len(image_bytes):,} байт")
            return image_bytes
            
        except requests.exceptions.Timeout:
            error_msg = f"Таймаут при загрузке изображения (>{timeout} сек)"
            logger.warning(f"⚠️ {error_msg}")
            last_error = error_msg
            if attempt < retries:
                continue
            raise ImageFetchError(error_msg)
        
        except requests.exceptions.RequestException as e:
            error_msg = f"Ошибка сети при загрузке: {str(e)}"
            logger.warning(f"⚠️ {error_msg}")
            last_error = error_msg
            if attempt < retries:
                continue
            raise ImageFetchError(error_msg)
        
        except ImageFetchError:
            # Пробрасываем дальше
            raise
        
        except Exception as e:
            error_msg = f"Неожиданная ошибка при загрузке изображения: {str(e)}"
            logger.error(f"❌ {error_msg}", exc_info=True)
            last_error = error_msg
            if attempt < retries:
                continue
            raise ImageFetchError(error_msg)
    
    # Если все попытки исчерпаны
    raise ImageFetchError(f"Не удалось загрузить изображение после {retries} попыток. Последняя ошибка: {last_error}")

