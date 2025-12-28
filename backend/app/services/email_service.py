"""
Email сервис для отправки писем через Resend API (HTTPS)
Полностью заменяет SMTP из-за блокировки портов провайдером
"""
import os
import logging
from typing import Optional
import resend

logger = logging.getLogger(__name__)

# Конфигурация из переменных окружения
EMAIL_PROVIDER = os.getenv("EMAIL_PROVIDER", "resend")
RESEND_API_KEY = os.getenv("RESEND_API_KEY")
EMAIL_FROM = os.getenv("EMAIL_FROM", "StoryHero <no-reply@storyhero.app>")

# Инициализация Resend API ключа
_resend_initialized = False


def _init_resend():
    """Инициализация Resend API"""
    global _resend_initialized
    
    if EMAIL_PROVIDER != "resend":
        logger.warning(f"[Email] Неподдерживаемый провайдер: {EMAIL_PROVIDER}. Используется только 'resend'")
        return False
    
    if not RESEND_API_KEY:
        logger.warning("[Email] RESEND_API_KEY не установлен в переменных окружения")
        return False
    
    if not _resend_initialized:
        try:
            # Устанавливаем API ключ для resend модуля
            resend.api_key = RESEND_API_KEY
            _resend_initialized = True
            logger.info("[Email] Resend API инициализирован")
        except Exception as e:
            logger.error(f"[Email] Ошибка инициализации Resend API: {e}")
            return False
    
    return True


async def send_email(
    to: str,
    subject: str,
    html: str,
    text: Optional[str] = None,
    attachments: Optional[list] = None
) -> None:
    """
    Отправка email через Resend API (HTTPS)
    
    Args:
        to: Email получателя
        subject: Тема письма
        html: HTML содержимое письма
        text: Текстовое содержимое (опционально, используется как fallback)
        attachments: Список вложений (опционально)
            Формат: [{"filename": "file.pdf", "content": bytes}]
    
    Raises:
        Exception: При ошибке отправки (логируется, но не падает весь backend)
    """
    if not RESEND_API_KEY:
        logger.warning("[Email] RESEND_API_KEY не установлен, пропускаем отправку email")
        return
    
    if not _init_resend():
        logger.warning("[Email] Resend API недоступен, пропускаем отправку email")
        return
    
    try:
        # Подготовка параметров для отправки
        params = {
            "from": EMAIL_FROM,
            "to": [to],
            "subject": subject,
            "html": html,
        }
        
        # Добавляем текстовую версию, если указана
        if text:
            params["text"] = text
        
        # Добавляем вложения, если указаны
        # Resend ожидает вложения в формате base64 строки
        if attachments:
            params["attachments"] = attachments
        
        # Отправка через Resend API
        result = resend.Emails.send(params)
        
        if result and hasattr(result, 'id'):
            logger.info(f"[Email] ✓ Письмо отправлено на {to} (ID: {result.id})")
        else:
            logger.warning(f"[Email] ⚠️ Письмо отправлено, но ответ не содержит ID: {result}")
            
    except Exception as e:
        # Логируем ошибку, но не падаем
        logger.error(f"[Email] ✗ Ошибка отправки письма на {to}: {e}")
        # Не выбрасываем исключение, чтобы не падал весь backend
        raise


def convert_text_to_html(text: str) -> str:
    """
    Конвертирует простой текст в базовый HTML
    
    Args:
        text: Текстовое содержимое
    
    Returns:
        HTML строка
    """
    # Заменяем переносы строк на <br>
    html = text.replace('\n', '<br>')
    
    # Обертываем в базовый HTML
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    </head>
    <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
        {html}
    </body>
    </html>
    """

