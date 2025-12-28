"""
Роутер для подписки StoryHero Premium
"""

import os
import logging
from datetime import datetime, timedelta, timezone
from uuid import UUID
from typing import Optional

import httpx

from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Subscription
from ..models.user import User
from ..core.deps import get_current_user
from ..services.email_service import send_email, convert_text_to_html

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/subscription", tags=["subscription"])

# Конфиги из env
SUBSCRIPTION_PRICE = int(os.getenv("SUBSCRIPTION_PRICE", "199"))
SUBSCRIPTION_DURATION_DAYS = int(os.getenv("SUBSCRIPTION_DURATION_DAYS", "30"))

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


class SubscriptionStatusResponse(BaseModel):
    is_subscribed: bool
    expires_at: str | None = None


class SubscriptionCreateRequest(BaseModel):
    price: int = SUBSCRIPTION_PRICE


class SubscriptionCreateResponse(BaseModel):
    status: str
    is_subscribed: bool
    expires_at: str
    subscription_id: str


async def _send_email(to: str, subject: str, body: str) -> None:
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
        logger.info(f"[Subscription][Email] ✓ Отправлено на {to}")
    except Exception as e:
        logger.error(f"[Subscription][Email] ✗ Ошибка отправки: {e}")


async def _send_telegram(text: str, message_thread_id: Optional[int] = None) -> None:
    """Отправка сообщения в Telegram с поддержкой тем (threads)"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        logger.warning("[Subscription][Telegram] Bot token or chat ID not configured, skipping telegram")
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
            logger.info(f"[Subscription][Telegram] Отправка в тему Telegram (thread_id: {message_thread_id})")
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage",
                json=params,
                timeout=10.0,
            )
            if response.status_code == 200:
                thread_info = f" (тема: {message_thread_id})" if message_thread_id else ""
                logger.info(f"[Subscription][Telegram] ✓ Отправлено в {chat_id}{thread_info}")
            else:
                logger.error(f"[Subscription][Telegram] ✗ Ошибка: {response.status_code} - {response.text}")
                if response.status_code == 400 and "chat not found" in response.text.lower():
                    logger.warning("[Subscription][Telegram] ⚠️ Возможно, нужно использовать chat_id вместо username. Получите chat_id через @userinfobot")
    except Exception as e:
        logger.error(f"[Subscription][Telegram] ✗ Ошибка отправки: {e}")


async def send_subscription_notification(user_email: str, expires_at: datetime) -> None:
    """
    Уведомление об оформлении подписки (Email разработчику + Telegram).
    """
    body = (
        "Новая подписка оформлена!\n\n"
        f"Email: {user_email}\n"
        f"Цена: {SUBSCRIPTION_PRICE} ₽\n"
        f"Действует до: {expires_at.strftime('%d.%m.%Y')}\n"
    )

    await _send_email(
        to=DEVELOPER_EMAIL,
        subject="🎉 Новая подписка StoryHero Premium",
        body=body,
    )

    telegram_msg = (
        "🎉 *Новая подписка!*\n"
        f"📧 {user_email}\n"
        f"💰 {SUBSCRIPTION_PRICE} ₽\n"
        f"📅 До: {expires_at.strftime('%d.%m.%Y')}"
    )
    # Отправляем в тему "Успешные оплаты" (thread_id: 45)
    thread_id = TELEGRAM_TOPICS.get("payments")
    await _send_telegram(telegram_msg, message_thread_id=thread_id)


@router.get("/status", response_model=SubscriptionStatusResponse)
async def get_subscription_status(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Проверка статуса подписки.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")

    now = datetime.now(timezone.utc)
    sub = db.query(Subscription).filter(
        Subscription.user_id == user_id,
        Subscription.is_active.is_(True),
        Subscription.expires_at.isnot(None),
        Subscription.expires_at > now,
    ).first()

    if sub:
        return SubscriptionStatusResponse(is_subscribed=True, expires_at=sub.expires_at.isoformat())
    return SubscriptionStatusResponse(is_subscribed=False, expires_at=None)


@router.post("/create", response_model=SubscriptionCreateResponse)
async def create_subscription(
    data: SubscriptionCreateRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Оформление подписки (демо/ручное подтверждение).
    """
    user_id = current_user.get("sub") or current_user.get("id")
    user_email = current_user.get("email", "unknown@email.com")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")

    now = datetime.now(timezone.utc)

    existing = db.query(Subscription).filter(
        Subscription.user_id == user_id,
        Subscription.is_active.is_(True),
        Subscription.expires_at.isnot(None),
        Subscription.expires_at > now,
    ).first()
    if existing:
        return SubscriptionCreateResponse(
            status="already_subscribed",
            is_subscribed=True,
            expires_at=existing.expires_at.isoformat(),
            subscription_id=str(existing.id),
        )

    if data.price != SUBSCRIPTION_PRICE:
        raise HTTPException(status_code=400, detail="Некорректная цена подписки")

    expires_at = now + timedelta(days=SUBSCRIPTION_DURATION_DAYS)

    # upsert по user_id (уникальный ключ)
    # если есть старая (неактивная/истёкшая) — обновим её
    sub = db.query(Subscription).filter(Subscription.user_id == user_id).first()
    if sub:
        sub.is_active = True
        sub.price = data.price
        sub.started_at = now
        sub.expires_at = expires_at
    else:
        sub = Subscription(
            user_id=user_id,
            is_active=True,
            price=data.price,
            started_at=now,
            expires_at=expires_at,
        )
        db.add(sub)

    # синхронизируем users.is_subscribed
    try:
        user_uuid = UUID(user_id)
        user = db.query(User).filter(User.id == user_uuid).first()
        if user:
            user.is_subscribed = True
    except Exception:
        pass

    db.commit()
    db.refresh(sub)

    # В тестах/внутренних вызовах background_tasks может быть None — не падаем
    if background_tasks is not None:
        background_tasks.add_task(send_subscription_notification, user_email=user_email, expires_at=expires_at)

    return SubscriptionCreateResponse(
        status="success",
        is_subscribed=True,
        expires_at=expires_at.isoformat(),
        subscription_id=str(sub.id),
    )


