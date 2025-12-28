"""
Роутер для отправки сообщений поддержки на Email и Telegram
"""
from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query, Request
from sqlalchemy.orm import Session
from sqlalchemy import desc, func
from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict
from datetime import datetime
from uuid import UUID
import os
import logging
import httpx

from ..db import get_db
from ..core.deps import get_current_user
from ..services.email_service import send_email as send_email_service, convert_text_to_html
from ..models.support_message import SupportMessage, SupportMessageReply

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/support", tags=["support"])

# Конфигурация уведомлений из переменных окружения
DEVELOPER_EMAIL = os.getenv("DEVELOPER_EMAIL", "maksim.yugov.89@gmail.com")
TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
# Для Telegram можно использовать chat_id (число) или username (без @)
_telegram_chat_id = os.getenv("TELEGRAM_ADMIN_CHAT_ID")
TELEGRAM_CHAT_ID = _telegram_chat_id if _telegram_chat_id else "Satir45"

# Конфигурация тем в Telegram группе (message_thread_id)
TELEGRAM_TOPICS = {
    "suggestion": 33,  # Пожелания
    "bug": 37,         # Ошибки
    "question": 35,    # Вопросы
    "orders": None,    # Заказы (если нужна отдельная тема)
    "payments": None,  # Платежи (если нужна отдельная тема)
}


# ==================== Pydantic Models ====================

class SupportMessageRequest(BaseModel):
    """Запрос на отправку сообщения поддержки"""
    name: str
    email: EmailStr
    type: str  # "suggestion", "bug", "question"
    message: str


class SupportMessageResponse(BaseModel):
    """Ответ на отправку сообщения поддержки"""
    message_id: str
    status: str
    message: str


class SupportMessageListItem(BaseModel):
    """Элемент списка сообщений поддержки"""
    id: str
    type: str
    message: str
    status: str
    created_at: datetime
    updated_at: datetime
    has_unread_replies: bool
    replies_count: int


class SupportMessagesListResponse(BaseModel):
    """Ответ со списком сообщений"""
    messages: List[SupportMessageListItem]
    total: int
    unread_count: int


class SupportMessageReplyItem(BaseModel):
    """Элемент ответа на сообщение"""
    id: str
    message_id: str
    reply_text: str
    replied_by: str
    is_read: bool
    created_at: datetime


class SupportMessageDetailResponse(BaseModel):
    """Детальная информация о сообщении с ответами"""
    message: dict
    replies: List[SupportMessageReplyItem]
    unread_replies_count: int


class UserReplyCreate(BaseModel):
    """Запрос на ответ пользователя"""
    message: str


class MessageStatusUpdate(BaseModel):
    """Обновление статуса сообщения"""
    status: str  # "closed"


# ==================== Helper Functions ====================

async def send_telegram(
    text: str, 
    message_thread_id: Optional[int] = None,
    inline_keyboard: Optional[dict] = None,
    chat_id: Optional[str] = None
):
    """Отправка сообщения в Telegram с поддержкой тем (threads) и inline-кнопок"""
    if not TELEGRAM_BOT_TOKEN:
        logger.warning("[Support] TELEGRAM_BOT_TOKEN не установлен, пропускаем отправку в Telegram")
        return
    
    # Если chat_id передан как параметр, используем его (для отправки в личные сообщения)
    # Иначе используем TELEGRAM_CHAT_ID (группа)
    if chat_id is None:
        chat_id = TELEGRAM_CHAT_ID
    
    # Пробуем преобразовать chat_id в число, если это возможно
    try:
        # Если это число в строке, преобразуем
        if isinstance(chat_id, str) and chat_id.lstrip('-').isdigit():
            chat_id = int(chat_id)
    except (ValueError, AttributeError):
        # Если не число, используем как username (без @)
        if isinstance(chat_id, str) and chat_id.startswith('@'):
            chat_id = chat_id[1:]
        pass
    
    try:
        # Формируем URL для отправки сообщения
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        
        # Параметры запроса
        params = {
            "chat_id": chat_id,
            "text": text,
            "parse_mode": "HTML"  # Используем HTML для лучшего форматирования
        }
        
        # Добавляем message_thread_id, если указан (для отправки в конкретную тему)
        if message_thread_id is not None:
            params["message_thread_id"] = message_thread_id
            logger.info(f"[Support] Отправка в тему Telegram (thread_id: {message_thread_id})")
        
        # Добавляем inline-кнопки, если указаны
        if inline_keyboard:
            params["reply_markup"] = inline_keyboard
        
        async with httpx.AsyncClient() as client:
            response = await client.post(url, json=params, timeout=10.0)
            
            if response.status_code == 200:
                thread_info = f" (тема: {message_thread_id})" if message_thread_id else ""
                logger.info(f"[Support] ✓ Сообщение отправлено в Telegram (chat_id: {chat_id}{thread_info})")
            else:
                logger.error(f"[Support] ✗ Ошибка отправки в Telegram: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"[Support] ✗ Ошибка отправки в Telegram: {e}")


async def send_support_notifications(
    message_id: str,
    name: str,
    email: str,
    message_type: str,
    message: str
):
    """Отправка уведомлений о сообщении поддержки на Email и Telegram"""
    
    # Определяем тип сообщения для заголовка
    type_labels = {
        "suggestion": "Пожелание",
        "bug": "Сообщение об ошибке",
        "question": "Вопрос"
    }
    type_label = type_labels.get(message_type, "Сообщение")
    
    # Формируем текст для Email
    email_text = f"""📧 НОВОЕ СООБЩЕНИЕ ПОДДЕРЖКИ: {type_label}

ID: {message_id}
👤 ОТПРАВИТЕЛЬ:
• Имя: {name}
• Email: {email}
• Тип: {type_label}

💬 СООБЩЕНИЕ:
{message}

📅 Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}

Ответить: /reply {message_id} {{текст ответа}}
"""
    
    # Формируем текст для Telegram (с HTML форматированием)
    # ВАЖНО: Включаем message_id для ответа администрации
    telegram_text = f"""🆘 <b>НОВОЕ ОБРАЩЕНИЕ В ПОДДЕРЖКУ</b>

🆔 <b>Ticket #{message_id[:8]}</b>
👤 Имя: {name}
📧 Email: <code>{email}</code>
📝 Тип: {type_label}
💬 Сообщение:
{message}

📅 {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    # Создаем inline-кнопку "Ответить"
    inline_keyboard = {
        "inline_keyboard": [
            [
                {
                    "text": "✍️ Ответить",
                    "callback_data": f"reply_ticket:{message_id}"
                }
            ]
        ]
    }
    
    # ВАЖНО: Email уведомления для сообщений поддержки (ошибки, пожелания, вопросы) отключены
    # Уведомления идут только в Telegram, так как с email неудобно отвечать
    # Email остается только для оплат и заказов (в payments.py и orders.py)
    
    # Отправка в Telegram (в соответствующую тему) с inline-кнопкой
    try:
        # Получаем message_thread_id для типа сообщения
        thread_id = TELEGRAM_TOPICS.get(message_type)
        await send_telegram(telegram_text, message_thread_id=thread_id, inline_keyboard=inline_keyboard)
        logger.info(f"[Support] ✓ Telegram уведомление отправлено с message_id: {message_id} и inline-кнопкой")
    except Exception as e:
        logger.error(f"[Support] Telegram send error: {e}")


# ==================== Endpoints ====================

@router.post("/send_message", response_model=SupportMessageResponse)
async def send_support_message(
    data: SupportMessageRequest,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Отправка сообщения поддержки.
    Сохраняет сообщение в БД и отправляет уведомления на Email и Telegram.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    logger.info(f"[Support] Получено сообщение поддержки от пользователя {user_id}")
    
    # Валидация данных
    if not data.name or not data.name.strip():
        raise HTTPException(status_code=400, detail="Имя обязательно")
    
    if not data.email or not data.email.strip():
        raise HTTPException(status_code=400, detail="Email обязателен")
    
    if not data.message or not data.message.strip():
        raise HTTPException(status_code=400, detail="Сообщение обязательно")
    
    if len(data.message.strip()) > 2000:
        raise HTTPException(status_code=400, detail="Сообщение слишком длинное (максимум 2000 символов)")
    
    if data.type not in ["suggestion", "bug", "question"]:
        raise HTTPException(status_code=400, detail="Некорректный тип сообщения")
    
    # Сохраняем сообщение в БД
    try:
        support_message = SupportMessage(
            user_id=str(user_id),
            name=data.name.strip(),
            email=data.email.strip(),
            type=data.type,
            message=data.message.strip(),
            status="new"
        )
        db.add(support_message)
        db.commit()
        db.refresh(support_message)
        
        message_id = str(support_message.id)
        logger.info(f"[Support] Сообщение сохранено в БД: message_id={message_id}")
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка сохранения сообщения в БД: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Ошибка сохранения сообщения")
    
    # Отправка уведомлений в фоне (не блокирует ответ)
    background_tasks.add_task(
        send_support_notifications,
        message_id=message_id,
        name=data.name.strip(),
        email=data.email.strip(),
        message_type=data.type,
        message=data.message.strip()
    )
    
    return SupportMessageResponse(
        message_id=message_id,
        status="sent",
        message="Сообщение отправлено. Мы свяжемся с вами в ближайшее время."
    )


@router.get("/messages", response_model=SupportMessagesListResponse)
async def get_support_messages(
    status: Optional[str] = Query(None, description="Фильтр по статусу: new, answered, closed"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить список всех сообщений текущего пользователя"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Базовый запрос для текущего пользователя
    query = db.query(SupportMessage).filter(SupportMessage.user_id == str(user_id))
    
    # Фильтр по статусу
    # КРИТИЧНО: Проверяем не только на None, но и на пустую строку
    if status and status.strip():
        if status not in ["new", "answered", "closed"]:
            raise HTTPException(status_code=400, detail="Некорректный статус")
        query = query.filter(SupportMessage.status == status)
    else:
        # По умолчанию исключаем закрытые сообщения (удаленные)
        query = query.filter(SupportMessage.status != "closed")
    
    # Получаем общее количество
    total = query.count()
    
    # Получаем сообщения с пагинацией, отсортированные по дате создания (новые сначала)
    messages = query.order_by(desc(SupportMessage.created_at)).offset(offset).limit(limit).all()
    
    # Формируем ответ с подсчетом непрочитанных ответов
    result_messages = []
    unread_count = 0
    
    for msg in messages:
        # Подсчитываем ответы и непрочитанные
        replies_count = db.query(func.count(SupportMessageReply.id)).filter(
            SupportMessageReply.message_id == msg.id
        ).scalar() or 0
        
        unread_replies_count = db.query(func.count(SupportMessageReply.id)).filter(
            SupportMessageReply.message_id == msg.id,
            SupportMessageReply.is_read == False
        ).scalar() or 0
        
        has_unread = unread_replies_count > 0
        if has_unread:
            unread_count += 1
        
        result_messages.append(SupportMessageListItem(
            id=str(msg.id),
            type=msg.type,
            message=msg.message,
            status=msg.status,
            created_at=msg.created_at,
            updated_at=msg.updated_at,
            has_unread_replies=has_unread,
            replies_count=replies_count
        ))
    
    return SupportMessagesListResponse(
        messages=result_messages,
        total=total,
        unread_count=unread_count
    )


@router.get("/messages/{message_id}", response_model=SupportMessageDetailResponse)
async def get_support_message_detail(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить конкретное сообщение со всеми ответами"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Преобразуем message_id в UUID
    try:
        message_uuid = UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат message_id")
    
    # Получаем сообщение, проверяя принадлежность пользователю
    message = db.query(SupportMessage).filter(
        SupportMessage.id == message_uuid,
        SupportMessage.user_id == str(user_id)
    ).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    
    # Получаем все ответы, отсортированные по дате (старые сначала)
    replies = db.query(SupportMessageReply).filter(
        SupportMessageReply.message_id == message_uuid
    ).order_by(SupportMessageReply.created_at.asc()).all()
    
    # Подсчитываем непрочитанные ответы
    unread_replies_count = db.query(func.count(SupportMessageReply.id)).filter(
        SupportMessageReply.message_id == message_uuid,
        SupportMessageReply.is_read == False
    ).scalar() or 0
    
    # Формируем ответ
    message_dict = {
        "id": str(message.id),
        "user_id": message.user_id,
        "name": message.name,
        "email": message.email,
        "type": message.type,
        "message": message.message,
        "status": message.status,
        "created_at": message.created_at.isoformat(),
        "updated_at": message.updated_at.isoformat() if message.updated_at else None
    }
    
    replies_list = [
        SupportMessageReplyItem(
            id=str(reply.id),
            message_id=str(reply.message_id),
            reply_text=reply.reply_text,
            replied_by=reply.replied_by or "unknown",
            is_read=reply.is_read,
            created_at=reply.created_at
        )
        for reply in replies
    ]
    
    return SupportMessageDetailResponse(
        message=message_dict,
        replies=replies_list,
        unread_replies_count=unread_replies_count
    )


@router.post("/messages/{message_id}/reply", response_model=SupportMessageResponse)
async def reply_to_support_message(
    message_id: str,
    data: UserReplyCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Отправить ответ пользователя на сообщение (продолжение диалога)"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Валидация
    if not data.message or not data.message.strip():
        raise HTTPException(status_code=400, detail="Сообщение обязательно")
    
    if len(data.message.strip()) > 2000:
        raise HTTPException(status_code=400, detail="Сообщение слишком длинное (максимум 2000 символов)")
    
    # Преобразуем message_id в UUID
    try:
        message_uuid = UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат message_id")
    
    # Проверяем, что сообщение принадлежит пользователю
    message = db.query(SupportMessage).filter(
        SupportMessage.id == message_uuid,
        SupportMessage.user_id == str(user_id)
    ).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    
    # Создаем ответ пользователя
    try:
        reply = SupportMessageReply(
            message_id=message_uuid,
            reply_text=data.message.strip(),
            replied_by=f"user_{user_id}",
            is_read=False
        )
        db.add(reply)
        
        # Обновляем updated_at сообщения
        message.updated_at = datetime.now()
        
        db.commit()
        db.refresh(reply)
        
        reply_id = str(reply.id)
        logger.info(f"[Support] Ответ пользователя сохранен: reply_id={reply_id}, message_id={message_id}")
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка сохранения ответа: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Ошибка сохранения ответа")
    
    # Отправляем уведомление администрации в фоне
    background_tasks.add_task(
        send_user_reply_notification,
        message_id=message_id,
        user_name=message.name,
        user_email=message.email,
        reply_text=data.message.strip()
    )
    
    return SupportMessageResponse(
        message_id=message_id,
        status="sent",
        message="Ваш ответ отправлен администрации"
    )


@router.put("/messages/{message_id}/replies/{reply_id}/read")
async def mark_reply_as_read(
    message_id: str,
    reply_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Пометить ответ администрации как прочитанный"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Преобразуем ID в UUID
    try:
        message_uuid = UUID(message_id)
        reply_uuid = UUID(reply_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат ID")
    
    # Проверяем, что сообщение принадлежит пользователю
    message = db.query(SupportMessage).filter(
        SupportMessage.id == message_uuid,
        SupportMessage.user_id == str(user_id)
    ).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    
    # Находим ответ
    reply = db.query(SupportMessageReply).filter(
        SupportMessageReply.id == reply_uuid,
        SupportMessageReply.message_id == message_uuid
    ).first()
    
    if not reply:
        raise HTTPException(status_code=404, detail="Ответ не найден")
    
    # Помечаем как прочитанный
    try:
        reply.is_read = True
        db.commit()
        logger.info(f"[Support] Ответ помечен как прочитанный: reply_id={reply_id}")
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка обновления ответа: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Ошибка обновления ответа")
    
    return {"status": "success", "message": "Ответ помечен как прочитанный"}


@router.put("/messages/{message_id}/status")
async def update_message_status(
    message_id: str,
    data: MessageStatusUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Обновить статус сообщения (пользователь может только закрыть)"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Пользователь может установить только "closed"
    if data.status != "closed":
        raise HTTPException(status_code=400, detail="Пользователь может только закрыть диалог (status='closed')")
    
    # Преобразуем message_id в UUID
    try:
        message_uuid = UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат message_id")
    
    # Проверяем, что сообщение принадлежит пользователю
    message = db.query(SupportMessage).filter(
        SupportMessage.id == message_uuid,
        SupportMessage.user_id == str(user_id)
    ).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    
    # Обновляем статус
    try:
        message.status = "closed"
        message.updated_at = datetime.now()
        db.commit()
        logger.info(f"[Support] Статус сообщения обновлен: message_id={message_id}, status=closed")
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка обновления статуса: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Ошибка обновления статуса")
    
    return {"status": "success", "message": "Статус обновлен"}


@router.delete("/messages/{message_id}")
async def delete_message(
    message_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Удалить сообщение поддержки (помечает как закрытое)"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Преобразуем message_id в UUID
    try:
        message_uuid = UUID(message_id)
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат message_id")
    
    # Проверяем, что сообщение принадлежит пользователю
    message = db.query(SupportMessage).filter(
        SupportMessage.id == message_uuid,
        SupportMessage.user_id == str(user_id)
    ).first()
    
    if not message:
        raise HTTPException(status_code=404, detail="Сообщение не найдено")
    
    # Помечаем сообщение как закрытое (удаленное)
    try:
        message.status = "closed"
        message.updated_at = datetime.now()
        db.commit()
        logger.info(f"[Support] Сообщение помечено как закрытое (удалено): message_id={message_id}")
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка удаления сообщения: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Ошибка удаления сообщения")
    
    return {"status": "success", "message": "Сообщение удалено"}


async def send_user_reply_notification(
    message_id: str,
    user_name: str,
    user_email: str,
    reply_text: str
):
    """Отправка уведомления администрации о новом ответе пользователя"""
    
    # Формируем текст для Email
    email_text = f"""📧 НОВЫЙ ОТВЕТ ПОЛЬЗОВАТЕЛЯ НА СООБЩЕНИЕ ПОДДЕРЖКИ

ID сообщения: {message_id}
👤 Пользователь: {user_name} ({user_email})

💬 Ответ пользователя:
{reply_text}

📅 Дата: {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    # Формируем текст для Telegram
    telegram_text = f"""📧 *НОВЫЙ ОТВЕТ ПОЛЬЗОВАТЕЛЯ*

ID сообщения: `{message_id}`
👤 Пользователь: {user_name} ({user_email})

💬 Ответ:
{reply_text}

📅 {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    # ВАЖНО: Email уведомления для ответов пользователей отключены
    # Уведомления идут только в Telegram, так как с email неудобно отвечать
    # Email остается только для оплат и заказов (в payments.py и orders.py)
    
    # Отправка в Telegram в ту же тему, что и исходное сообщение
    # Нужно получить тип исходного сообщения из БД
    try:
        from ..db import SessionLocal
        from uuid import UUID as UUIDType
        db = SessionLocal()
        try:
            message_uuid = UUIDType(message_id)
            original_message = db.query(SupportMessage).filter(
                SupportMessage.id == message_uuid
            ).first()
            
            if original_message:
                # Отправляем в ту же тему, что и исходное сообщение
                thread_id = TELEGRAM_TOPICS.get(original_message.type)
                
                # КРИТИЧНО: Добавляем inline-кнопку "Ответить" для каждого ответа пользователя
                # Это позволяет администрации отвечать на повторные сообщения пользователя
                inline_keyboard = {
                    "inline_keyboard": [
                        [
                            {
                                "text": "✍️ Ответить",
                                "callback_data": f"reply_ticket:{message_id}"
                            }
                        ]
                    ]
                }
                
                await send_telegram(telegram_text, message_thread_id=thread_id, inline_keyboard=inline_keyboard)
                logger.info(f"[Support] ✓ Telegram уведомление отправлено о новом ответе пользователя в тему {thread_id} с кнопкой 'Ответить'")
            else:
                # Fallback: отправляем в основную тему
                # Даже в fallback добавляем кнопку для возможности ответа
                inline_keyboard = {
                    "inline_keyboard": [
                        [
                            {
                                "text": "✍️ Ответить",
                                "callback_data": f"reply_ticket:{message_id}"
                            }
                        ]
                    ]
                }
                await send_telegram(telegram_text, message_thread_id=None, inline_keyboard=inline_keyboard)
                logger.info(f"[Support] ✓ Telegram уведомление отправлено о новом ответе пользователя (основная тема) с кнопкой 'Ответить'")
        finally:
            db.close()
    except Exception as e:
        logger.error(f"[Support] Telegram send error: {e}")


# ==================== Функции для обработки ответов администрации ====================

async def create_admin_reply(
    message_id: str,
    reply_text: str,
    replied_by: str = "telegram",
    db: Session = None
):
    """
    Создать ответ администрации на сообщение поддержки.
    Используется при обработке команды /reply из Telegram.
    """
    try:
        message_uuid = UUID(message_id)
    except ValueError:
        raise ValueError(f"Неверный формат message_id: {message_id}")
    
    if not db:
        from ..db import SessionLocal
        db = SessionLocal()
        should_close = True
    else:
        should_close = False
    
    try:
        # Находим сообщение
        message = db.query(SupportMessage).filter(
            SupportMessage.id == message_uuid
        ).first()
        
        if not message:
            raise ValueError(f"Сообщение не найдено: {message_id}")
        
        # Создаем ответ
        reply = SupportMessageReply(
            message_id=message_uuid,
            reply_text=reply_text,
            replied_by=replied_by,
            is_read=False
        )
        db.add(reply)
        
        # Обновляем статус сообщения
        if message.status == "new":
            message.status = "answered"
        message.updated_at = datetime.now()
        
        # КРИТИЧНО: Фиксируем изменения в БД СРАЗУ, чтобы ответ был доступен пользователю немедленно
        db.commit()
        # КРИТИЧНО: Обновляем объект reply из БД, чтобы получить все поля (включая created_at)
        db.refresh(reply)
        # КРИТИЧНО: Явно обновляем сессию БД, чтобы изменения были видны другим запросам
        db.expire_all()
        
        logger.info(f"[Support] ✅ Ответ администрации создан и зафиксирован в БД: reply_id={str(reply.id)}, message_id={message_id}")
        
        # ВАЖНО: Email уведомления для ответов администрации отключены
        # Ответы администрации не отправляются по email, так как с email неудобно отвечать
        # Пользователь видит ответы администрации в приложении через API
        # Email остается только для оплат и заказов (в payments.py и orders.py)
        logger.info(f"[Support] ✓ Ответ администрации сохранен в БД, email уведомления отключены для сообщений поддержки")
        
        return reply
    except Exception as e:
        db.rollback()
        logger.error(f"[Support] Ошибка создания ответа администрации: {e}", exc_info=True)
        raise
    finally:
        if should_close:
            db.close()


async def send_admin_reply_email_to_user(
    message_id: str,
    user_name: str,
    user_email: str,
    original_message: str,
    reply_text: str
):
    """Отправка email пользователю с ответом администрации"""
    
    email_text = f"""Тема: Ответ на ваше обращение в поддержку StoryHero

Здравствуйте, {user_name}!

Администрация ответила на ваше обращение:

Ваше сообщение:
"{original_message}"

Ответ администрации:
"{reply_text}"

Вы можете ответить в приложении StoryHero или ответить на это письмо.

С уважением,
Команда StoryHero
"""
    
    try:
        html_content = convert_text_to_html(email_text)
        await send_email_service(
            to=user_email,
            subject="Ответ на ваше обращение в поддержку StoryHero",
            html=html_content,
            text=email_text
        )
        logger.info(f"[Support] ✓ Email с ответом администрации отправлен пользователю {user_email}")
    except Exception as e:
        logger.error(f"[Support] Ошибка отправки email пользователю: {e}", exc_info=True)


async def send_admin_reply_to_telegram(
    message_id: str,
    message_type: str,
    reply_text: str,
    reply_id: str
):
    """
    Отправка ответа администрации в Telegram в ту же тему, что и исходное сообщение.
    Включает inline-кнопку для продолжения диалога.
    """
    # Определяем thread_id по типу сообщения (та же тема, куда было отправлено исходное сообщение)
    thread_id = TELEGRAM_TOPICS.get(message_type)
    
    # Формируем текст ответа
    telegram_text = f"""💬 <b>ОТВЕТ АДМИНИСТРАЦИИ</b>

🆔 Ticket #{message_id[:8]}

{reply_text}

📅 {datetime.now().strftime('%d.%m.%Y %H:%M')}
"""
    
    # Создаем inline-кнопку "Ответить" для продолжения диалога
    inline_keyboard = {
        "inline_keyboard": [
            [
                {
                    "text": "✍️ Ответить",
                    "callback_data": f"reply_ticket:{message_id}"
                }
            ]
        ]
    }
    
    try:
        await send_telegram(telegram_text, message_thread_id=thread_id, inline_keyboard=inline_keyboard)
        logger.info(f"[Support] ✓ Ответ администрации отправлен в Telegram в тему {thread_id} для message_id={message_id}")
    except Exception as e:
        logger.error(f"[Support] Ошибка отправки ответа администрации в Telegram: {e}", exc_info=True)


@router.post("/admin/reply")
async def admin_reply_endpoint(
    message_id: str = Query(..., description="ID сообщения поддержки"),
    reply_text: str = Query(..., description="Текст ответа администрации"),
    admin_token: Optional[str] = Query(None, description="Секретный токен администрации (опционально для тестирования)"),
    db: Session = Depends(get_db)
):
    """
    Эндпоинт для обработки ответов администрации из Telegram.
    
    ВАЖНО: Этот эндпоинт должен быть защищен!
    В продакшене используйте:
    - Проверку секретного токена (ADMIN_SECRET_TOKEN)
    - Ограничение доступа по IP
    - Проверку прав пользователя Telegram
    
    Использование:
    POST /api/v1/support/admin/reply?message_id={uuid}&reply_text={текст}&admin_token={token}
    """
    # Проверка токена (если установлен)
    admin_secret = os.getenv("ADMIN_SECRET_TOKEN")
    if admin_secret:
        if not admin_token or admin_token != admin_secret:
            logger.warning(f"[Support] Попытка доступа к /admin/reply без правильного токена")
            raise HTTPException(status_code=403, detail="Доступ запрещен: неверный токен")
    
    # Валидация
    if not message_id or not message_id.strip():
        raise HTTPException(status_code=400, detail="message_id обязателен")
    
    if not reply_text or not reply_text.strip():
        raise HTTPException(status_code=400, detail="reply_text обязателен")
    
    if len(reply_text.strip()) > 2000:
        raise HTTPException(status_code=400, detail="Ответ слишком длинный (максимум 2000 символов)")
    
    try:
        reply = await create_admin_reply(
            message_id=message_id.strip(),
            reply_text=reply_text.strip(),
            replied_by="telegram",
            db=db
        )
        
        logger.info(f"[Support] ✅ Ответ администрации создан: reply_id={str(reply.id)}, message_id={message_id}")
        
        return {
            "status": "success",
            "message": "Ответ администрации создан и отправлен пользователю",
            "reply_id": str(reply.id),
            "message_id": message_id
        }
    except ValueError as e:
        logger.error(f"[Support] Ошибка валидации: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"[Support] Ошибка обработки ответа администрации: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка создания ответа: {str(e)}")


# ==================== Функции для обработки inline-кнопок ====================

# Временное хранилище для режима ответа администрации
# В продакшене лучше использовать Redis или БД
_admin_reply_mode: Dict[int, str] = {}  # {admin_telegram_id: message_id}


def set_admin_reply_mode(admin_telegram_id: int, message_id: str):
    """Установить режим ответа для администратора"""
    global _admin_reply_mode
    _admin_reply_mode[admin_telegram_id] = message_id
    logger.info(f"[Support] Режим ответа установлен: admin_id={admin_telegram_id}, message_id={message_id}")


def get_admin_reply_ticket(admin_telegram_id: int) -> Optional[str]:
    """Получить message_id, на который администратор отвечает"""
    global _admin_reply_mode
    return _admin_reply_mode.get(admin_telegram_id)


def clear_reply_mode(admin_telegram_id: int):
    """Очистить режим ответа для администратора"""
    global _admin_reply_mode
    if admin_telegram_id in _admin_reply_mode:
        del _admin_reply_mode[admin_telegram_id]
        logger.info(f"[Support] Режим ответа очищен: admin_id={admin_telegram_id}")


def is_admin(telegram_user_id: int) -> bool:
    """Проверка, является ли пользователь Telegram администратором"""
    admin_ids_str = os.getenv("TELEGRAM_ADMIN_IDS", "")
    if not admin_ids_str:
        # Если список не установлен, разрешаем всем (только для тестирования!)
        logger.warning("[Support] TELEGRAM_ADMIN_IDS не установлен, разрешаем всем (НЕ БЕЗОПАСНО!)")
        return True
    
    admin_ids = [int(id.strip()) for id in admin_ids_str.split(",") if id.strip().isdigit()]
    return telegram_user_id in admin_ids


async def answer_callback_query(callback_query_id: str, text: str, show_alert: bool = False):
    """Ответить на callback_query от Telegram"""
    if not TELEGRAM_BOT_TOKEN:
        return
    
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/answerCallbackQuery"
        params = {
            "callback_query_id": callback_query_id,
            "text": text,
            "show_alert": show_alert
        }
        
        async with httpx.AsyncClient() as client:
            response = await client.post(url, json=params, timeout=5.0)
            if response.status_code == 200:
                logger.info(f"[Support] ✓ Callback query ответ отправлен: {callback_query_id}")
            else:
                logger.error(f"[Support] ✗ Ошибка ответа на callback: {response.status_code} - {response.text}")
    except Exception as e:
        logger.error(f"[Support] ✗ Ошибка ответа на callback: {e}")


@router.post("/telegram/webhook")
async def telegram_webhook(
    request: Request,
    x_telegram_bot_api_secret_token: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Webhook для обработки обновлений от Telegram бота.
    
    Обрабатывает:
    1. callback_query - нажатие на inline-кнопку "Ответить"
    2. message - обычное сообщение от администратора (если он в режиме ответа)
    
    Безопасность:
    - Проверка секретного токена (если установлен TELEGRAM_WEBHOOK_SECRET)
    - Проверка прав администратора (TELEGRAM_ADMIN_IDS)
    """
    # Проверка секретного токена (если установлен в Telegram)
    webhook_secret = os.getenv("TELEGRAM_WEBHOOK_SECRET")
    if webhook_secret:
        # Получаем токен из заголовка
        if not x_telegram_bot_api_secret_token:
            # Пробуем получить из заголовка напрямую
            x_telegram_bot_api_secret_token = request.headers.get("X-Telegram-Bot-Api-Secret-Token")
        
        if not x_telegram_bot_api_secret_token or x_telegram_bot_api_secret_token != webhook_secret:
            logger.warning(f"[Support][Webhook] Попытка доступа с неверным секретным токеном")
            raise HTTPException(status_code=403, detail="Invalid secret token")
    
    try:
        update = await request.json()
        logger.debug(f"[Support][Webhook] Получено обновление от Telegram: {list(update.keys())}")
        
        # Обработка callback_query (нажатие на inline-кнопку)
        if "callback_query" in update:
            cb = update["callback_query"]
            callback_data = cb.get("data", "")
            callback_query_id = cb.get("id")
            admin_telegram_id = cb.get("from", {}).get("id")
            
            logger.info(f"[Support][Webhook] Callback query: data={callback_data}, admin_id={admin_telegram_id}")
            
            # Проверка прав доступа
            if not is_admin(admin_telegram_id):
                await answer_callback_query(
                    callback_query_id,
                    "❌ У вас нет прав для выполнения этой команды",
                    show_alert=True
                )
                return {"ok": True}
            
            # Обработка нажатия на кнопку "Ответить"
            if callback_data.startswith("reply_ticket:"):
                message_id = callback_data.split(":", 1)[1]
                
                # Устанавливаем режим ответа
                set_admin_reply_mode(admin_telegram_id, message_id)
                
                # Отвечаем на callback
                await answer_callback_query(
                    callback_query_id,
                    f"✍️ Напишите ответ для Ticket #{message_id[:8]}"
                )
                
                logger.info(f"[Support][Webhook] Режим ответа установлен для admin_id={admin_telegram_id}, message_id={message_id}")
                return {"ok": True}
        
        # Обработка обычного сообщения (ответ администратора)
        if "message" in update:
            msg = update["message"]
            admin_telegram_id = msg.get("from", {}).get("id")
            message_text = msg.get("text", "").strip()
            
            # Проверяем, находится ли администратор в режиме ответа
            message_id = get_admin_reply_ticket(admin_telegram_id)
            
            if message_id and message_text:
                logger.info(f"[Support][Webhook] Получен ответ от admin_id={admin_telegram_id} для message_id={message_id}")
                
                # Проверка прав доступа
                if not is_admin(admin_telegram_id):
                    logger.warning(f"[Support][Webhook] Попытка ответа от неавторизованного пользователя: {admin_telegram_id}")
                    return {"ok": True}
                
                # Создаем ответ
                try:
                    # КРИТИЧНО: Создаем ответ и сразу фиксируем в БД
                    reply = await create_admin_reply(
                        message_id=message_id,
                        reply_text=message_text,
                        replied_by=f"telegram_{admin_telegram_id}",
                        db=db
                    )
                    
                    # Очищаем режим ответа
                    clear_reply_mode(admin_telegram_id)
                    
                    # ВАЖНО: НЕ отправляем подтверждение администратору в тему или личные сообщения
                    # Это предотвращает дубляж и не засоряет тему
                    # Администратор видит свой ответ в теме (исходное сообщение), подтверждение не нужно
                    logger.info(f"[Support][Webhook] ✓ Ответ создан и зафиксирован в БД, подтверждение не отправляется (избегаем дубляжа)")
                    
                    logger.info(f"[Support][Webhook] ✅ Ответ создан: reply_id={str(reply.id)}")
                except Exception as e:
                    logger.error(f"[Support][Webhook] Ошибка создания ответа: {e}", exc_info=True)
                    # Отправляем ошибку администратору
                    chat_id = msg.get("chat", {}).get("id")
                    if chat_id:
                        error_text = f"❌ <b>Ошибка отправки ответа:</b>\n{str(e)}"
                        await send_telegram(error_text, message_thread_id=None)
            
            return {"ok": True}
        
        return {"ok": True}
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Support][Webhook] Ошибка обработки webhook: {e}", exc_info=True)
        return {"ok": False, "error": str(e)}


@router.get("/telegram/webhook/info")
async def get_telegram_webhook_info():
    """
    Получить информацию о текущем состоянии webhook в Telegram.
    Полезно для проверки настройки webhook.
    """
    if not TELEGRAM_BOT_TOKEN:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN не установлен")
    
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getWebhookInfo"
        async with httpx.AsyncClient() as client:
            response = await client.get(url, timeout=10.0)
            
            if response.status_code == 200:
                data = response.json()
                if data.get("ok"):
                    webhook_info = data.get("result", {})
                    logger.info(f"[Support] Webhook info получена: {webhook_info}")
                    return {
                        "status": "success",
                        "webhook_info": webhook_info
                    }
                else:
                    return {
                        "status": "error",
                        "message": data.get("description", "Unknown error")
                    }
            else:
                logger.error(f"[Support] Ошибка получения webhook info: {response.status_code} - {response.text}")
                raise HTTPException(status_code=500, detail="Ошибка получения информации о webhook")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Support] Ошибка получения webhook info: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")


@router.post("/telegram/webhook/setup")
async def setup_telegram_webhook(
    webhook_url: str = Query(..., description="URL для webhook (например, https://storyhero.ru/api/v1/support/telegram/webhook)"),
    secret_token: Optional[str] = Query(None, description="Секретный токен для безопасности (опционально)")
):
    """
    Настроить webhook для Telegram бота.
    
    ВАЖНО: Этот эндпоинт должен быть защищен в продакшене!
    Используйте только для первоначальной настройки или через защищенный доступ.
    """
    if not TELEGRAM_BOT_TOKEN:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN не установлен")
    
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/setWebhook"
        params = {
            "url": webhook_url
        }
        
        # Добавляем секретный токен, если указан
        if secret_token:
            params["secret_token"] = secret_token
        
        async with httpx.AsyncClient() as client:
            response = await client.post(url, json=params, timeout=10.0)
            
            if response.status_code == 200:
                data = response.json()
                if data.get("ok"):
                    logger.info(f"[Support] Webhook настроен: {webhook_url}")
                    return {
                        "status": "success",
                        "message": "Webhook успешно настроен",
                        "webhook_url": webhook_url,
                        "result": data.get("result", {})
                    }
                else:
                    error_msg = data.get("description", "Unknown error")
                    logger.error(f"[Support] Ошибка настройки webhook: {error_msg}")
                    raise HTTPException(status_code=400, detail=error_msg)
            else:
                logger.error(f"[Support] Ошибка настройки webhook: {response.status_code} - {response.text}")
                raise HTTPException(status_code=500, detail="Ошибка настройки webhook")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Support] Ошибка настройки webhook: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")


@router.post("/telegram/webhook/delete")
async def delete_telegram_webhook():
    """
    Удалить webhook для Telegram бота.
    Полезно для отключения webhook или переключения на polling.
    """
    if not TELEGRAM_BOT_TOKEN:
        raise HTTPException(status_code=400, detail="TELEGRAM_BOT_TOKEN не установлен")
    
    try:
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/deleteWebhook"
        async with httpx.AsyncClient() as client:
            response = await client.post(url, timeout=10.0)
            
            if response.status_code == 200:
                data = response.json()
                if data.get("ok"):
                    logger.info(f"[Support] Webhook удален")
                    return {
                        "status": "success",
                        "message": "Webhook успешно удален",
                        "result": data.get("result", {})
                    }
                else:
                    error_msg = data.get("description", "Unknown error")
                    logger.error(f"[Support] Ошибка удаления webhook: {error_msg}")
                    raise HTTPException(status_code=400, detail=error_msg)
            else:
                logger.error(f"[Support] Ошибка удаления webhook: {response.status_code} - {response.text}")
                raise HTTPException(status_code=500, detail="Ошибка удаления webhook")
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"[Support] Ошибка удаления webhook: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=f"Ошибка: {str(e)}")

