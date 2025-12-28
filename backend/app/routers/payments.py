"""
Роутер для работы с оплатой книг
"""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
import logging
import os
import httpx
from datetime import datetime

from ..db import get_db
from ..models import Book, PrintOrder
from ..core.deps import get_current_user
from ..config.pricing import validate_price
from ..services.email_service import send_email, convert_text_to_html

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/payments", tags=["payments"])

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
    "payments": 45,  # Успешные оплаты (PDF, премиум, заказы на печать)
}


# ==================== Pydantic Models ====================

class PaymentCreateRequest(BaseModel):
    book_id: str


class PaymentCreateResponse(BaseModel):
    payment_url: Optional[str] = None  # None для демо-режима
    payment_id: str


class PaymentConfirmRequest(BaseModel):
    book_id: str


class PaymentConfirmResponse(BaseModel):
    status: str
    is_paid: bool


class PaymentStatusResponse(BaseModel):
    is_paid: bool
    book_id: str
    pdf_url: Optional[str] = None


# ==================== Models for Print Orders ====================

class PrintOrderData(BaseModel):
    """Данные заказа на печать"""
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


class PrintOrderPaymentCreateRequest(BaseModel):
    """Запрос на создание платежа для заказа на печать"""
    book_id: str
    amount: int
    order_data: PrintOrderData


class PrintOrderPaymentCreateResponse(BaseModel):
    """Ответ на создание платежа для заказа на печать"""
    payment_url: Optional[str] = None  # None для демо-режима
    payment_id: str


class PrintOrderPaymentConfirmRequest(BaseModel):
    """Запрос на подтверждение оплаты заказа на печать"""
    book_id: str
    order_data: PrintOrderData  # Данные заказа передаются при подтверждении


class PrintOrderPaymentConfirmResponse(BaseModel):
    """Ответ на подтверждение оплаты заказа на печать"""
    status: str
    order_id: Optional[str] = None  # ID созданного заказа


# ==================== Helper Functions ====================

async def send_email_notification(to: str, subject: str, body: str):
    """Отправка email через Resend API"""
    try:
        # Конвертируем текст в HTML
        html_content = convert_text_to_html(body)
        
        # Отправка через Resend API
        await send_email(
            to=to,
            subject=subject,
            html=html_content,
            text=body  # Текстовая версия для fallback
        )
    except Exception as e:
        logger.error(f"[Payments][Email] ✗ Ошибка отправки: {e}")


async def send_telegram(text: str, message_thread_id: Optional[int] = None):
    """Отправка сообщения в Telegram с поддержкой тем (threads)"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("[Payments][Telegram] Bot token or chat ID not configured, skipping telegram")
        return
    
    try:
        # Поддержка username (без @) и chat_id (число)
        chat_id = TELEGRAM_CHAT_ID
        # Если это не число, значит это username - убираем @ если есть
        if not chat_id.lstrip('-').isdigit():
            # Убираем @ если есть, Telegram API принимает username без @
            chat_id = chat_id.lstrip('@')
        
        # Параметры запроса
        params = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "Markdown"
        }
        
        # Добавляем message_thread_id, если указан (для отправки в конкретную тему)
        if message_thread_id is not None:
            params["message_thread_id"] = message_thread_id
            logger.info(f"[Payments][Telegram] Отправка в тему Telegram (thread_id: {message_thread_id})")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                json=params,
                timeout=10.0
            )
            if response.status_code == 200:
                thread_info = f" (тема: {message_thread_id})" if message_thread_id else ""
                logger.info(f"[Payments][Telegram] ✓ Сообщение отправлено в {chat_id}{thread_info}")
            else:
                logger.error(f"[Payments][Telegram] ✗ Ошибка: {response.status_code} - {response.text}")
                # Если ошибка из-за username, подсказываем про chat_id
                if response.status_code == 400 and "chat not found" in response.text.lower():
                    logger.warning("[Payments][Telegram] ⚠️ Возможно, нужно использовать chat_id вместо username. Получите chat_id через @userinfobot")
    except Exception as e:
        logger.error(f"[Payments][Telegram] ✗ Ошибка отправки: {e}")


async def send_payment_notifications(book_title: str, book_id: str, user_email: str, pdf_url: Optional[str] = None):
    """Отправка уведомлений о покупке PDF книги на Email и Telegram"""
    
    logger.info(f"[Payments] 📤 Начало отправки уведомлений о покупке PDF: book_title={book_title}, book_id={book_id}, user_email={user_email}")
    
    # Формируем текст для Email
    email_text = f"""💰 НОВАЯ ПОКУПКА PDF КНИГИ

📚 Книга: {book_title}
🆔 ID: {book_id[:8]}

👤 КЛИЕНТ:
• Email: {user_email}

📄 PDF: {pdf_url if pdf_url else 'Генерируется...'}

📅 Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    # 1. Отправка Email
    try:
        html_content = convert_text_to_html(email_text)
        await send_email(
            to=DEVELOPER_EMAIL,
            subject=f"💰 Новая покупка PDF - {book_title}",
            html=html_content,
            text=email_text
        )
        logger.info(f"[Payments] ✓ Email отправлен на {DEVELOPER_EMAIL}")
    except Exception as e:
        logger.error(f"[Payments] ✗ Email send error: {e}", exc_info=True)
    
    # 2. Отправка в Telegram (краткое сообщение с тестовым чеком)
    telegram_text = f"""💰 *ОПЛАТА PDF КНИГИ*

📚 *{book_title}*
🆔 `#{book_id[:8]}`

👤 Клиент: {user_email}

🧾 *Чек об оплате (тестовый):*
• Сумма: 299 ₽
• Статус: ✅ Оплачено
• Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
• Способ: Тестовая оплата"""
    
    try:
        # Отправляем в тему "Успешные оплаты" (thread_id: 45)
        thread_id = TELEGRAM_TOPICS.get("payments")
        logger.info(f"[Payments] 📤 Отправка Telegram уведомления в тему 'Подтверждение об оплате' (thread_id: {thread_id})")
        await send_telegram(telegram_text, message_thread_id=thread_id)
        logger.info(f"[Payments] ✓ Telegram уведомление отправлено в тему 'Подтверждение об оплате' (thread_id: {thread_id})")
    except Exception as e:
        logger.error(f"[Payments] ✗ Telegram send error: {e}", exc_info=True)


async def send_print_order_payment_notifications(
    book_title: str,
    order_id: str,
    total_price: int,
    customer_name: str,
    customer_phone: str,
    user_email: str,
    size: str = "",
    pages: int = 0,
    binding: str = "",
    packaging: str = ""
):
    """Отправка уведомлений об оплате заказа на печать на Email и Telegram"""
    
    # Формируем текст для Email
    email_text = f"""💰 ОПЛАТА ЗАКАЗА НА ПЕЧАТЬ

📚 Книга: {book_title}
🆔 ID заказа: {order_id[:8]}

💰 Стоимость: {total_price} ₽

👤 КЛИЕНТ:
• Имя: {customer_name}
• Телефон: {customer_phone}
• Email: {user_email}

📦 ПАРАМЕТРЫ ЗАКАЗА:
• Формат: {size}
• Страниц: {pages}
• Переплёт: {binding}
• Упаковка: {packaging}

🧾 ЧЕК ОБ ОПЛАТЕ (тестовый):
• Сумма: {total_price} ₽
• Статус: ✅ Оплачено (печатный вариант)
• Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
• Способ: Тестовая оплата
"""
    
    # 1. Отправка Email
    try:
        html_content = convert_text_to_html(email_text)
        await send_email(
            to=DEVELOPER_EMAIL,
            subject=f"💰 Оплата заказа на печать - {book_title}",
            html=html_content,
            text=email_text
        )
        logger.info(f"[Payments][PrintOrder] ✓ Email отправлен на {DEVELOPER_EMAIL}")
    except Exception as e:
        logger.error(f"[Payments][PrintOrder] Email send error: {e}")
    
    # 2. Отправка в Telegram (краткое сообщение с деталями заказа, БЕЗ PDF)
    telegram_text = f"""💰 *ОПЛАТА ЗАКАЗА НА ПЕЧАТЬ*

📚 *{book_title}*
🆔 Заказ `#{order_id[:8]}`

👤 Клиент: {customer_name} ({user_email})

📦 *Параметры заказа:*
• Формат: {size}
• Страниц: {pages}
• Переплёт: {binding}
• Упаковка: {packaging}

💰 *Стоимость: {total_price} ₽*

🧾 *Чек об оплате (тестовый):*
• Сумма: {total_price} ₽
• Статус: ✅ Оплачено (печатный вариант)
• Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
• Способ: Тестовая оплата"""
    
    try:
        # Отправляем в тему "Успешные оплаты" (thread_id: 45)
        thread_id = TELEGRAM_TOPICS.get("payments")
        await send_telegram(telegram_text, message_thread_id=thread_id)
        logger.info(f"[Payments][PrintOrder] ✓ Telegram уведомление отправлено")
    except Exception as e:
        logger.error(f"[Payments][PrintOrder] Telegram send error: {e}")


# ==================== Endpoints ====================

@router.post("/create", response_model=PaymentCreateResponse)
async def create_payment(
    data: PaymentCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создание платежа для книги.
    В демо-режиме возвращает payment_url=None.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Проверяем существование книги и принадлежность пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Проверяем, не оплачена ли уже (is_paid хранится как строка "true"/"false")
    if book.is_paid and book.is_paid.lower() == "true":
        raise HTTPException(status_code=400, detail="Книга уже оплачена")
    
    # В демо-режиме возвращаем payment_url=None
    # В продакшене здесь будет интеграция с платёжной системой (ЮKassa, Stripe и т.д.)
    logger.info(f"[Payments] Создание платежа для книги {book_uuid}, пользователь {user_id}")
    
    # Генерируем payment_id (в продакшене это будет ID от платёжной системы)
    import uuid
    payment_id = str(uuid.uuid4())
    
    return PaymentCreateResponse(
        payment_url=None,  # В демо-режиме нет URL
        payment_id=payment_id
    )


@router.post("/confirm", response_model=PaymentConfirmResponse)
async def confirm_payment(
    data: PaymentConfirmRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Подтверждение оплаты (webhook от платёжной системы или демо-режим).
    Отправляет уведомления на Email и Telegram в фоновом режиме.
    """
    logger.info(f"[Payments] 🔵 ВХОД В confirm_payment: book_id={data.book_id}")
    user_id = current_user.get("sub") or current_user.get("id")
    user_email = current_user.get("email", "unknown@email.com")
    logger.info(f"[Payments] 🔵 user_id={user_id}, user_email={user_email}")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Находим книгу
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Проверяем, была ли книга уже оплачена
    was_already_paid = book.is_paid and book.is_paid.lower() == "true"
    
    # ВРЕМЕННО ДЛЯ ТЕСТИРОВАНИЯ: Всегда устанавливаем статус оплаты
    # Устанавливаем статус оплаты
    book.is_paid = "true"
    
    # Если книга финализирована, но PDF еще не сгенерирован, генерируем его
    if book.status == "final" and not book.final_pdf_url:
        logger.info(f"[Payments] Книга {book_uuid} финализирована, но PDF отсутствует. Генерируем PDF...")
        try:
            from ..scripts.generate_pdf_for_book import generate_pdf
            exit_code = await generate_pdf(str(book_uuid))
            if exit_code == 0:
                db.refresh(book)
                logger.info(f"[Payments] ✓ PDF успешно сгенерирован для книги {book_uuid}")
            else:
                logger.warning(f"[Payments] ⚠️ PDF не был сгенерирован (exit_code={exit_code}) для книги {book_uuid}")
        except Exception as e:
            logger.error(f"[Payments] ✗ Ошибка генерации PDF для книги {book_uuid}: {str(e)}", exc_info=True)
            # Продолжаем выполнение, даже если PDF не сгенерирован
    
    db.commit()
    db.refresh(book)
    
    if not was_already_paid:
        logger.info(f"[Payments] ✓ Оплата подтверждена для книги {book_uuid}, пользователь {user_id}")
    else:
        logger.info(f"[Payments] Книга {book_uuid} уже оплачена, отправляем тестовое уведомление (заглушка для тестирования)")
    
    # ВРЕМЕННО ДЛЯ ТЕСТИРОВАНИЯ: Отправляем уведомления синхронно, чтобы убедиться, что они отправляются
    # Отправка уведомлений (для тестирования отправляем синхронно, чтобы видеть ошибки)
    logger.info(f"[Payments] 🔍 ПОДГОТОВКА К ОТПРАВКЕ УВЕДОМЛЕНИЙ: book_title={book.title}, book_id={str(book.id)}, user_email={user_email}, pdf_url={book.final_pdf_url}")
    try:
        logger.info(f"[Payments] 📤 НАЧАЛО ОТПРАВКИ УВЕДОМЛЕНИЙ О ПОКУПКЕ PDF (заглушка для тестирования)")
        await send_payment_notifications(
            book_title=book.title,
            book_id=str(book.id),
            user_email=user_email,
            pdf_url=book.final_pdf_url
        )
        logger.info(f"[Payments] ✅ УВЕДОМЛЕНИЯ УСПЕШНО ОТПРАВЛЕНЫ")
    except Exception as e:
        logger.error(f"[Payments] ✗ КРИТИЧЕСКАЯ ОШИБКА ОТПРАВКИ УВЕДОМЛЕНИЙ: {e}", exc_info=True)
        # Не прерываем выполнение, даже если уведомления не отправились
    
    logger.info(f"[Payments] ✅ Скачивание PDF разблокировано для книги {book_uuid}")
    
    return PaymentConfirmResponse(status="success", is_paid=True)


@router.get("/status/{book_id}", response_model=PaymentStatusResponse)
async def get_payment_status(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Проверка статуса оплаты книги.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Находим книгу
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Возвращаем статус и PDF URL
    # is_paid хранится как строка "true"/"false"
    is_paid_bool = book.is_paid and book.is_paid.lower() == "true"
    
    # ВРЕМЕННО ДЛЯ ТЕСТИРОВАНИЯ: Разблокируем PDF независимо от оплаты
    # В продакшене должно быть: pdf_url = book.final_pdf_url if is_paid_bool else None
    pdf_url = book.final_pdf_url  # Всегда возвращаем PDF URL, если он есть
    
    logger.info(f"[Payments] Статус оплаты для книги {book_id}: is_paid={is_paid_bool}, pdf_url={'есть' if pdf_url else 'нет'}")
    
    return PaymentStatusResponse(
        is_paid=is_paid_bool,
        book_id=str(book.id),
        pdf_url=pdf_url
    )


# ==================== Print Order Payment Endpoints ====================

@router.post("/create_print_order", response_model=PrintOrderPaymentCreateResponse)
async def create_print_order_payment(
    data: PrintOrderPaymentCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создание платежа для заказа на печать книги.
    В демо-режиме возвращает payment_url=None.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Проверяем существование книги и принадлежность пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Валидация цены на бэкенде
    if not validate_price(data.order_data.size, data.order_data.pages, 
                         data.order_data.binding, data.order_data.packaging, 
                         data.amount):
        logger.warning(f"[Payments][PrintOrder] ✗ Некорректная цена: size={data.order_data.size}, pages={data.order_data.pages}, binding={data.order_data.binding}, packaging={data.order_data.packaging}, price={data.amount}")
        raise HTTPException(status_code=400, detail="Некорректная цена заказа")
    
    # Проверяем, что сумма совпадает с total_price из order_data
    if data.amount != data.order_data.total_price:
        raise HTTPException(status_code=400, detail="Сумма платежа не совпадает с ценой заказа")
    
    # В демо-режиме возвращаем payment_url=None
    # В продакшене здесь будет интеграция с платёжной системой (ЮKassa, Stripe и т.д.)
    logger.info(f"[Payments][PrintOrder] Создание платежа для заказа на печать книги {book_uuid}, пользователь {user_id}, сумма {data.amount}")
    
    # Генерируем payment_id (в продакшене это будет ID от платёжной системы)
    import uuid
    payment_id = str(uuid.uuid4())
    
    return PrintOrderPaymentCreateResponse(
        payment_url=None,  # В демо-режиме нет URL
        payment_id=payment_id
    )


@router.post("/confirm_print_order", response_model=PrintOrderPaymentConfirmResponse)
async def confirm_print_order_payment(
    data: PrintOrderPaymentConfirmRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Подтверждение оплаты заказа на печать.
    После подтверждения автоматически создаёт заказ и отправляет уведомления.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    user_email = current_user.get("email", "unknown@email.com")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация book_id
    try:
        book_uuid = UUID(data.book_id)
    except (ValueError, TypeError):
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {data.book_id}")
    
    # Находим книгу
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == user_id
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена или не принадлежит вам")
    
    # Валидация цены на бэкенде
    if not validate_price(data.order_data.size, data.order_data.pages, 
                         data.order_data.binding, data.order_data.packaging, 
                         data.order_data.total_price):
        logger.warning(f"[Payments][PrintOrder] ✗ Некорректная цена при подтверждении")
        raise HTTPException(status_code=400, detail="Некорректная цена заказа")
    
    logger.info(f"[Payments][PrintOrder] ✓ Оплата подтверждена для заказа на печать книги {book_uuid}, пользователь {user_id}")
    
    # Создаём заказ на печать
    # Импортируем модели и функции из orders.py
    from ..routers.orders import PrintOrderCreate, send_order_notifications
    
    order_data = PrintOrderCreate(
        book_id=data.book_id,
        book_title=data.order_data.book_title,
        size=data.order_data.size,
        pages=data.order_data.pages,
        binding=data.order_data.binding,
        packaging=data.order_data.packaging,
        total_price=data.order_data.total_price,
        customer_name=data.order_data.customer_name,
        customer_phone=data.order_data.customer_phone,
        customer_address=data.order_data.customer_address,
        comment=data.order_data.comment or ""
    )
    
    # Создаём заказ в базе данных
    db_order = PrintOrder(
        user_id=user_id,
        book_id=book_uuid,
        book_title=order_data.book_title,
        size=order_data.size,
        pages=order_data.pages,
        binding=order_data.binding,
        packaging=order_data.packaging,
        total_price=order_data.total_price,
        customer_name=order_data.customer_name,
        customer_phone=order_data.customer_phone,
        customer_address=order_data.customer_address,
        comment=order_data.comment,
        status="pending"
    )
    
    db.add(db_order)
    db.commit()
    db.refresh(db_order)
    
    order_id = str(db_order.id)
    logger.info(f"[Payments][PrintOrder] ✓ Заказ создан: {order_id}")
    
    # Отправка уведомлений в фоне (не блокирует ответ)
    # 1. Уведомление о создании заказа (с PDF файлом)
    background_tasks.add_task(
        send_order_notifications,
        order=order_data,
        order_id=order_id,
        user_email=user_email,
        db=db
    )
    
    # 2. Уведомление об оплате заказа
    background_tasks.add_task(
        send_print_order_payment_notifications,
        book_title=order_data.book_title,
        order_id=order_id,
        total_price=order_data.total_price,
        customer_name=order_data.customer_name,
        customer_phone=order_data.customer_phone,
        user_email=user_email,
        size=order_data.size,
        pages=order_data.pages,
        binding=order_data.binding,
        packaging=order_data.packaging
    )
    
    return PrintOrderPaymentConfirmResponse(
        status="success",
        order_id=order_id
    )

