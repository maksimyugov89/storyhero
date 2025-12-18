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
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

from ..db import get_db
from ..models import Book, PrintOrder
from ..core.deps import get_current_user
from ..config.pricing import validate_price

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/orders", tags=["orders"])

# Конфигурация уведомлений из переменных окружения
DEVELOPER_EMAIL = os.getenv("DEVELOPER_EMAIL", "maksim.yugov.89@gmail.com")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.getenv("TELEGRAM_ADMIN_CHAT_ID")

# SMTP конфигурация
SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = os.getenv("SMTP_USER")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")


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

async def send_email(to: str, subject: str, body: str):
    """Отправка email через SMTP"""
    if not SMTP_USER or not SMTP_PASSWORD:
        logger.warning("[Email] SMTP credentials not configured, skipping email")
        return
    
    try:
        msg = MIMEMultipart()
        msg['From'] = SMTP_USER
        msg['To'] = to
        msg['Subject'] = subject
        msg.attach(MIMEText(body, 'plain', 'utf-8'))
        
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as server:
            server.starttls()
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        
        logger.info(f"[Email] ✓ Письмо отправлено на {to}")
    except Exception as e:
        logger.error(f"[Email] ✗ Ошибка отправки: {e}")


async def send_telegram(text: str):
    """Отправка сообщения в Telegram"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("[Telegram] Bot token or chat ID not configured, skipping telegram")
        return
    
    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                json={
                    "chat_id": TELEGRAM_CHAT_ID,
                    "text": text,
                    "parse_mode": "Markdown"
                },
                timeout=10.0
            )
            if response.status_code == 200:
                logger.info("[Telegram] ✓ Сообщение отправлено")
            else:
                logger.error(f"[Telegram] ✗ Ошибка: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"[Telegram] ✗ Ошибка отправки: {e}")


async def send_order_notifications(order: PrintOrderCreate, order_id: str, user_email: str):
    """Отправка уведомлений о новом заказе на Email и Telegram"""
    
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
    
    # 1. Отправка Email
    try:
        await send_email(
            to=DEVELOPER_EMAIL,
            subject=f"🛒 Новый заказ печатной книги - {order.book_title}",
            body=order_text
        )
    except Exception as e:
        logger.error(f"[Orders] Email send error: {e}")
    
    # 2. Отправка в Telegram (с Markdown форматированием)
    telegram_text = f"""🛒 *НОВЫЙ ЗАКАЗ* `#{order_id[:8]}`

📚 *{order.book_title}*

📦 Параметры:
• Формат: {order.size}
• Страниц: {order.pages}
• Переплёт: {order.binding}
• Упаковка: {order.packaging}

💰 *Стоимость: {order.total_price} ₽*

👤 Клиент:
• {order.customer_name}
• 📞 `{order.customer_phone}`
• 📧 {user_email}
• 📍 {order.customer_address}"""

    if order.comment:
        telegram_text += f"\n• 💬 {order.comment}"
    
    try:
        await send_telegram(telegram_text)
    except Exception as e:
        logger.error(f"[Orders] Telegram send error: {e}")


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
    background_tasks.add_task(
        send_order_notifications,
        order=order,
        order_id=order_id,
        user_email=user_email
    )
    
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

