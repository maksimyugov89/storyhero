"""
Роутер для заказов печатных книг с уведомлениями Email и Telegram
"""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime
import httpx
import os
import logging
import base64

from ..db import get_db
from ..models import Book, PrintOrder
from ..core.deps import get_current_user
from ..config.pricing import validate_price
from ..services.email_service import send_email as send_email_service, convert_text_to_html

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/orders", tags=["orders"])

# Конфигурация уведомлений из переменных окружения
DEVELOPER_EMAIL = os.getenv("DEVELOPER_EMAIL", "maksim.yugov.89@gmail.com")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
# Для Telegram можно использовать chat_id (число) или username (без @)
# Примеры: "123456789" (chat_id) или "Satir45" (username)
# По умолчанию: @Satir45
_telegram_chat_id = os.getenv("TELEGRAM_ADMIN_CHAT_ID")
TELEGRAM_CHAT_ID = _telegram_chat_id if _telegram_chat_id else "Satir45"

# Конфигурация тем в Telegram группе (message_thread_id)
TELEGRAM_TOPICS = {
    "orders": 1438324505,  # Заказы на печать (тема "Заказы")
    "payments": 45,  # Успешные оплаты (PDF, премиум, заказы на печать)
}


# ==================== Pydantic Models ====================

class PrintOrderCreate(BaseModel):
    book_id: str
    book_title: str
    size: str
    pages: int
    binding: str
    packaging: str
    total_price: int
    customer_name: str
    customer_phone: str
    customer_address: str
    comment: Optional[str] = ""


class PrintOrderResponse(BaseModel):
    status: str
    order_id: str
    message: str


class OrderStatusResponse(BaseModel):
    order_id: str
    status: str
    book_title: str
    total_price: int
    created_at: datetime


# ==================== Helper Functions ====================

async def send_email_with_pdf(to: str, subject: str, body: str, pdf_path: Optional[str] = None):
    """Отправка email через Resend API с поддержкой PDF вложений"""
    try:
        # Конвертируем текст в HTML
        html_content = convert_text_to_html(body)
        
        # Подготавливаем вложения, если есть PDF
        attachments = None
        if pdf_path and os.path.exists(pdf_path):
            try:
                with open(pdf_path, 'rb') as pdf_file:
                    pdf_content = pdf_file.read()
                    pdf_filename = os.path.basename(pdf_path)
                    # Resend требует base64 кодирование для вложений
                    pdf_base64 = base64.b64encode(pdf_content).decode('utf-8')
                    attachments = [{
                        "filename": pdf_filename,
                        "content": pdf_base64
                    }]
                    logger.info(f"[Email] PDF вложение подготовлено: {pdf_filename} ({len(pdf_content)} байт)")
            except Exception as e:
                logger.warning(f"[Email] Не удалось подготовить PDF вложение: {e}")
        
        # Отправка через Resend API
        await send_email_service(
            to=to,
            subject=subject,
            html=html_content,
            text=body,  # Текстовая версия для fallback
            attachments=attachments
        )
    except Exception as e:
        logger.error(f"[Email] ✗ Ошибка отправки: {e}")


async def send_telegram(text: str, pdf_path: Optional[str] = None, message_thread_id: Optional[int] = None):
    """Отправка сообщения в Telegram с возможностью прикрепления PDF файла и поддержкой тем (threads)"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("[Telegram] Bot token or chat ID not configured, skipping telegram")
        return
    
    try:
        # Поддержка username (без @) и chat_id (число)
        chat_id = TELEGRAM_CHAT_ID
        # Если это не число, значит это username - добавляем @ если нужно
        if not chat_id.lstrip('-').isdigit():
            # Убираем @ если есть, Telegram API принимает username без @
            chat_id = chat_id.lstrip('@')
        
        async with httpx.AsyncClient(timeout=30.0) as client:
            # Сначала отправляем полное текстовое сообщение
            message_params = {
                "chat_id": chat_id,
                "text": text,
                "parse_mode": "Markdown"
            }
            
            # Добавляем message_thread_id, если указан (для отправки в конкретную тему)
            if message_thread_id is not None:
                message_params["message_thread_id"] = message_thread_id
                logger.info(f"[Orders][Telegram] ℹ️ Отправка текстового сообщения в чат {chat_id} (thread_id: {message_thread_id})")
            else:
                logger.info(f"[Orders][Telegram] Отправка в основную тему группы (без thread_id)")
            
            logger.debug(f"[Orders][Telegram] Параметры sendMessage: chat_id={chat_id}, thread_id={message_thread_id}, text_length={len(text)}")
            
            response = await client.post(
                f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                json=message_params,
                timeout=10.0
            )
            if response.status_code == 200:
                response_data = response.json()
                message_id = response_data.get("result", {}).get("message_id")
                thread_info = f" (thread_id: {message_thread_id})" if message_thread_id is not None else " (основная тема)"
                logger.info(f"[Telegram] ✓ Полное сообщение отправлено в {chat_id}{thread_info}, message_id: {message_id}")
                logger.info(f"[Orders][Telegram] ℹ️ Параметры sendMessage: chat_id={chat_id}, thread_id={message_thread_id}, text_length={len(text)}")
                logger.debug(f"[Telegram] Текст сообщения (первые 200 символов): {text[:200]}...")
            else:
                logger.error(f"[Telegram] ✗ Ошибка: {response.status_code} - {response.text}")
                error_text = response.text.lower()
                logger.info(f"[Telegram] 🔍 Анализ ошибки: message_thread_id={message_thread_id}, error_text содержит 'thread': {'thread' in error_text}, содержит 'message thread not found': {'message thread not found' in error_text}")
                # Если ошибка с thread_id, пробуем отправить без thread_id
                if message_thread_id is not None and ("message thread not found" in error_text or "thread" in error_text):
                    logger.warning(f"[Telegram] ⚠️ Проблема с thread_id={message_thread_id}, пробуем отправить без thread_id")
                    message_params_without_thread = {k: v for k, v in message_params.items() if k != 'message_thread_id'}
                    logger.info(f"[Telegram] 🔄 Повторная отправка сообщения без thread_id...")
                    response_retry = await client.post(
                        f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                        json=message_params_without_thread,
                        timeout=10.0
                    )
                    if response_retry.status_code == 200:
                        response_data = response_retry.json()
                        message_id = response_data.get("result", {}).get("message_id")
                        logger.info(f"[Telegram] ✓ Сообщение отправлено без thread_id (основная тема), message_id: {message_id}")
                    else:
                        logger.error(f"[Telegram] ✗ Ошибка отправки без thread_id: {response_retry.status_code} - {response_retry.text}")
                # Если ошибка из-за username, подсказываем про chat_id
                elif response.status_code == 400 and "chat not found" in error_text:
                    logger.warning("[Telegram] ⚠️ Возможно, нужно использовать chat_id вместо username. Получите chat_id через @userinfobot")
            
            # Если есть PDF файл, отправляем его отдельным сообщением
            if pdf_path and os.path.exists(pdf_path):
                try:
                    pdf_filename = os.path.basename(pdf_path)
                    with open(pdf_path, 'rb') as pdf_file:
                        files = {'document': (pdf_filename, pdf_file, 'application/pdf')}
                        data = {'chat_id': chat_id, 'caption': f'📄 PDF файл книги: {pdf_filename}'}
                        
                        # Добавляем message_thread_id для PDF файла, если указан
                        if message_thread_id is not None:
                            data['message_thread_id'] = message_thread_id
                            logger.info(f"[Orders][Telegram] ℹ️ Отправка PDF файла в чат {chat_id} (thread_id: {message_thread_id})")
                        else:
                            logger.info(f"[Orders][Telegram] PDF отправляется в основную тему группы (без thread_id)")
                        
                        logger.info(f"[Orders][Telegram] ℹ️ Параметры sendDocument: chat_id={chat_id}, thread_id={message_thread_id}, filename={pdf_filename}")
                        
                        response = await client.post(
                            f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendDocument",
                            data=data,
                            files=files,
                            timeout=30.0
                        )
                        
                        if response.status_code == 200:
                            response_data = response.json()
                            message_id = response_data.get("result", {}).get("message_id")
                            thread_info = f" (thread_id: {message_thread_id})" if message_thread_id is not None else " (основная тема)"
                            logger.info(f"[Telegram] ✓ PDF файл отправлен: {pdf_filename}{thread_info}, message_id: {message_id}")
                        else:
                            logger.error(f"[Telegram] ✗ Ошибка отправки PDF: {response.status_code} - {response.text}")
                            error_text = response.text.lower()
                            logger.info(f"[Telegram] 🔍 Анализ ошибки PDF: message_thread_id={message_thread_id}, error_text содержит 'thread': {'thread' in error_text}")
                            # Если ошибка с thread_id, пробуем отправить без thread_id
                            if message_thread_id is not None and ("message thread not found" in error_text or "thread" in error_text):
                                logger.warning(f"[Telegram] ⚠️ Проблема с thread_id={message_thread_id} для PDF, пробуем без thread_id")
                                data_without_thread = {k: v for k, v in data.items() if k != 'message_thread_id'}
                                logger.info(f"[Telegram] 🔄 Повторная отправка PDF без thread_id...")
                                # Нужно снова открыть файл для повторной отправки
                                with open(pdf_path, 'rb') as pdf_file_retry:
                                    files_retry = {'document': (pdf_filename, pdf_file_retry, 'application/pdf')}
                                    response_retry = await client.post(
                                        f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendDocument",
                                        data=data_without_thread,
                                        files=files_retry,
                                        timeout=30.0
                                    )
                                    if response_retry.status_code == 200:
                                        logger.info(f"[Telegram] ✓ PDF файл отправлен без thread_id: {pdf_filename}")
                                    else:
                                        logger.error(f"[Telegram] ✗ Ошибка отправки PDF без thread_id: {response_retry.status_code} - {response_retry.text}")
                except Exception as e:
                    logger.error(f"[Telegram] ✗ Ошибка при отправке PDF: {e}")
                    
    except Exception as e:
        logger.error(f"[Telegram] ✗ Ошибка отправки: {e}")


async def send_order_notifications(order: PrintOrderCreate, order_id: str, user_email: str, db: Session = None):
    """Отправка уведомлений о новом заказе на Email и Telegram с прикреплением PDF файла"""
    
    # Получаем PDF файл книги
    pdf_path = None
    
    # Создаем новую сессию БД, если не передана
    if not db:
        from ..db import SessionLocal
        db = SessionLocal()
        should_close_db = True
    else:
        should_close_db = False
    
    try:
        try:
            from uuid import UUID
            book_uuid = UUID(order.book_id)
            book = db.query(Book).filter(Book.id == book_uuid).first()
            
            if book and book.final_pdf_url:
                # Конвертируем URL в локальный путь
                pdf_url = book.final_pdf_url
                pdf_path = None
                
                if pdf_url.startswith('/static/'):
                    # Локальный путь: /static/books/{book_id}/final.pdf
                    # Конвертируем в полный путь: /var/www/storyhero/uploads/books/{book_id}/final.pdf
                    pdf_path = pdf_url.replace('/static/', '/var/www/storyhero/uploads/')
                elif pdf_url.startswith('https://') or pdf_url.startswith('http://'):
                    # Если это HTTP/HTTPS URL, пробуем сначала конвертировать в локальный путь
                    # Формат: https://storyhero.ru/static/books/{book_id}/final.pdf
                    if '/static/' in pdf_url:
                        # Извлекаем путь после /static/
                        static_part = pdf_url.split('/static/', 1)[1]
                        pdf_path = f'/var/www/storyhero/uploads/{static_part}'
                    else:
                        # Если не удалось конвертировать, скачиваем файл временно
                        try:
                            import tempfile
                            async with httpx.AsyncClient() as client:
                                response = await client.get(pdf_url, timeout=30.0)
                                if response.status_code == 200:
                                    with tempfile.NamedTemporaryFile(delete=False, suffix='.pdf') as tmp_file:
                                        tmp_file.write(response.content)
                                        pdf_path = tmp_file.name
                                        logger.info(f"[Orders] PDF скачан во временный файл: {pdf_path}")
                        except Exception as e:
                            logger.warning(f"[Orders] Не удалось скачать PDF: {e}")
                
                # Проверяем существование файла
                if pdf_path:
                    if os.path.exists(pdf_path):
                        logger.info(f"[Orders] ✅ PDF файл найден: {pdf_path} ({os.path.getsize(pdf_path)} байт)")
                    else:
                        logger.warning(f"[Orders] ⚠️ PDF файл не найден: {pdf_path}")
                        pdf_path = None
                else:
                    logger.warning(f"[Orders] ⚠️ Не удалось определить путь к PDF файлу из URL: {pdf_url}")
            else:
                logger.warning(f"[Orders] ⚠️ У книги нет final_pdf_url: book_id={order.book_id}")
        except Exception as e:
            logger.warning(f"[Orders] Ошибка при получении PDF: {e}", exc_info=True)
    finally:
        # Закрываем сессию БД, если мы её создали
        if should_close_db:
            try:
                db.close()
            except Exception as e:
                logger.warning(f"[Orders] Ошибка при закрытии сессии БД: {e}")
    
    # Формируем текст заказа для Email
    order_text = f"""🛒 НОВЫЙ ЗАКАЗ ПЕЧАТНОЙ КНИГИ #{order_id[:8]}

📚 Книга: {order.book_title}

📦 ПАРАМЕТРЫ:
• Формат: {order.size}
• Страниц: {order.pages}
• Переплёт: {order.binding}
• Упаковка: {order.packaging}

💰 СТОИМОСТЬ: {order.total_price} ₽

👤 КЛИЕНТ:
• Имя: {order.customer_name}
• Телефон: {order.customer_phone}
• Email: {user_email}
• Адрес: {order.customer_address}
• Комментарий: {order.comment or 'Нет'}

📅 Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    if pdf_path:
        order_text += f"\n📄 PDF файл книги прикреплен к письму."
    
    # 1. Отправка Email через Resend API
    try:
        await send_email_with_pdf(
            to=DEVELOPER_EMAIL,
            subject=f"🛒 Новый заказ печатной книги - {order.book_title}",
            body=order_text,
            pdf_path=pdf_path
        )
    except Exception as e:
        logger.error(f"[Orders] Email send error: {e}")
    
    # 2. Отправка в Telegram (с Markdown форматированием)
    # Формируем полное сообщение, как в Email
    # ВАЖНО: Экранируем специальные символы Markdown в данных пользователя
    def escape_markdown(text: str) -> str:
        """Экранирует специальные символы Markdown (только основные)"""
        if not text:
            return ""
        # Экранируем только основные символы Markdown, которые могут сломать форматирование
        # Не экранируем точку, восклицательный знак и другие часто используемые символы
        special_chars = ['_', '*', '[', ']', '(', ')', '~', '`', '>', '#', '|']
        for char in special_chars:
            text = text.replace(char, f'\\{char}')
        return text
    
    # Экранируем данные пользователя
    safe_title = escape_markdown(order.book_title)
    safe_name = escape_markdown(order.customer_name)
    safe_phone = escape_markdown(order.customer_phone)
    safe_email = escape_markdown(user_email)
    safe_address = escape_markdown(order.customer_address)
    safe_comment = escape_markdown(order.comment) if order.comment else None
    
    telegram_text = f"""🛒 *НОВЫЙ ЗАКАЗ ПЕЧАТНОЙ КНИГИ* #{order_id[:8]}

📚 *{safe_title}*

📦 *ПАРАМЕТРЫ:*
• Формат: {order.size}
• Страниц: {order.pages}
• Переплёт: {order.binding}
• Упаковка: {order.packaging}

💰 *СТОИМОСТЬ: {order.total_price} ₽*

👤 *КЛИЕНТ:*
• Имя: {safe_name}
• Телефон: {safe_phone}
• Email: {safe_email}
• Адрес: {safe_address}"""

    if safe_comment:
        telegram_text += f"\n• Комментарий: {safe_comment}"
    
    telegram_text += f"\n\n📅 Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}"
    
    if pdf_path:
        telegram_text += f"\n\n📄 PDF файл книги прикреплен."
    
    logger.info(f"[Orders] 📤 Отправка Telegram сообщения (длина текста: {len(telegram_text)} символов)")
    logger.debug(f"[Orders] Текст сообщения: {telegram_text[:500]}...")
    
    try:
        # Отправляем в тему "Заказы" (thread_id: 63)
        # Для заказов отправляем полное сообщение с PDF в тему "Заказы"
        thread_id = TELEGRAM_TOPICS.get("orders")
        await send_telegram(telegram_text, pdf_path=pdf_path, message_thread_id=thread_id)
        logger.info(f"[Orders] ✓ Telegram уведомление о заказе отправлено в тему 'Заказы' (thread_id: {thread_id})")
    except Exception as e:
        logger.error(f"[Orders] Telegram send error: {e}", exc_info=True)
    
    # Удаляем временный файл, если он был создан
    if pdf_path and pdf_path.startswith('/tmp'):
        try:
            os.unlink(pdf_path)
            logger.debug(f"[Orders] Временный PDF файл удален: {pdf_path}")
        except Exception as e:
            logger.warning(f"[Orders] Не удалось удалить временный файл: {e}")


# ==================== Endpoints ====================

@router.post("/print", response_model=PrintOrderResponse)
async def create_print_order(
    order: PrintOrderCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создание заказа на печать книги.
    Отправляет уведомления на Email и Telegram в фоновом режиме.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    user_email = current_user.get("email", "unknown@email.com")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    logger.info(f"[Orders] Создание заказа печати от пользователя {user_id}")
    
    # 1. Валидация цены на бэкенде (ОБЯЗАТЕЛЬНО!)
    if not validate_price(order.size, order.pages, order.binding, order.packaging, order.total_price):
        logger.warning(f"[Orders] ✗ Некорректная цена: size={order.size}, pages={order.pages}, binding={order.binding}, packaging={order.packaging}, price={order.total_price}")
        raise HTTPException(status_code=400, detail="Некорректная цена заказа")
    
    # 2. Валидация book_id
    try:
        book_uuid = UUID(order.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {order.book_id}")
    
    # 3. Проверка существования книги
    book = db.query(Book).filter(Book.id == book_uuid).first()
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена")
    
    # Проверяем принадлежность книги пользователю
    if book.user_id != user_id:
        raise HTTPException(status_code=403, detail="Книга не принадлежит вам")
    
    # 4. Создание заказа
    db_order = PrintOrder(
        user_id=user_id,
        book_id=book_uuid,
        book_title=order.book_title,
        size=order.size,
        pages=order.pages,
        binding=order.binding,
        packaging=order.packaging,
        total_price=order.total_price,
        customer_name=order.customer_name,
        customer_phone=order.customer_phone,
        customer_address=order.customer_address,
        comment=order.comment,
        status="pending"
    )
    
    db.add(db_order)
    db.commit()
    db.refresh(db_order)
    
    order_id = str(db_order.id)
    logger.info(f"[Orders] ✓ Заказ создан: {order_id}")
    
    # 5. Отправка уведомлений в фоне (не блокирует ответ)
    # ВАЖНО: Уведомления НЕ отправляются здесь, так как заказ должен создаваться
    # только через /payments/confirm_print_order после оплаты, где уведомления уже отправляются.
    # Этот эндпоинт оставлен для совместимости, но не должен использоваться в основном flow.
    # Если нужна отправка уведомлений для прямого создания заказа, раскомментируйте код ниже:
    # background_tasks.add_task(
    #     send_order_notifications,
    #     order=order,
    #     order_id=order_id,
    #     user_email=user_email
    # )
    
    return PrintOrderResponse(
        status="success",
        order_id=order_id,
        message="Заказ успешно оформлен"
    )


@router.get("/my", response_model=list[OrderStatusResponse])
async def get_my_orders(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получение списка заказов текущего пользователя.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    orders = db.query(PrintOrder).filter(
        PrintOrder.user_id == user_id
    ).order_by(PrintOrder.created_at.desc()).all()
    
    return [
        OrderStatusResponse(
            order_id=str(o.id),
            status=o.status,
            book_title=o.book_title,
            total_price=o.total_price,
            created_at=o.created_at
        )
        for o in orders
    ]


@router.get("/{order_id}", response_model=OrderStatusResponse)
async def get_order_status(
    order_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получение статуса конкретного заказа.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    try:
        order_uuid = UUID(order_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат order_id: {order_id}")
    
    order = db.query(PrintOrder).filter(
        PrintOrder.id == order_uuid,
        PrintOrder.user_id == user_id
    ).first()
    
    if not order:
        raise HTTPException(status_code=404, detail="Заказ не найден")
    
    return OrderStatusResponse(
        order_id=str(order.id),
        status=order.status,
        book_title=order.book_title,
        total_price=order.total_price,
        created_at=order.created_at
    )

