"""
Сервис для обслуживания подписок (деактивация истёкших и синхронизация флага users.is_subscribed)
"""

from datetime import datetime, timezone
import logging
from sqlalchemy.orm import Session
from uuid import UUID

from ..db import SessionLocal
from ..models import Subscription
from ..models.user import User

logger = logging.getLogger(__name__)


def check_and_update_user_subscription_status(db: Session, user_id: str) -> bool:
    """
    Проверяет и обновляет статус подписки пользователя.
    Синхронизирует флаг users.is_subscribed с активными подписками.
    
    Args:
        db: Сессия базы данных
        user_id: UUID пользователя (строка)
    
    Returns:
        bool: True если у пользователя есть активная подписка, False иначе
    """
    try:
        # Преобразуем user_id в UUID для поиска пользователя
        try:
            user_uuid = UUID(user_id)
        except (ValueError, TypeError):
            logger.error(f"[Subscription] Некорректный user_id: {user_id}")
            return False
        
        # Получаем пользователя
        user = db.query(User).filter(User.id == user_uuid).first()
        if not user:
            logger.warning(f"[Subscription] Пользователь {user_id} не найден")
            return False
        
        # Проверяем активные подписки пользователя
        from sqlalchemy import or_
        now = datetime.now(timezone.utc)
        active_subscription = db.query(Subscription).filter(
            Subscription.user_id == user_id,
            Subscription.is_active.is_(True),
            # Проверяем, что подписка не истекла (если expires_at установлен)
            or_(Subscription.expires_at.is_(None), Subscription.expires_at > now)
        ).first()
        
        # Синхронизируем флаг is_subscribed
        had_subscription = user.is_subscribed
        user.is_subscribed = active_subscription is not None
        
        # Коммитим изменения только если статус изменился
        if had_subscription != user.is_subscribed:
            db.commit()
            logger.info(
                f"[Subscription] Статус подписки пользователя {user_id} обновлен: "
                f"{had_subscription} -> {user.is_subscribed}"
            )
        
        return user.is_subscribed
        
    except Exception as e:
        db.rollback()
        logger.error(
            f"[Subscription] Ошибка проверки подписки пользователя {user_id}: {e}",
            exc_info=True
        )
        return False


def check_expired_subscriptions() -> int:
    """
    Деактивирует истёкшие подписки и сбрасывает users.is_subscribed.
    Запускается по расписанию (cron/apscheduler).

    Returns:
        int: количество деактивированных подписок
    """
    db = SessionLocal()
    try:
        now = datetime.now(timezone.utc)
        expired = db.query(Subscription).filter(
            Subscription.is_active.is_(True),
            Subscription.expires_at.isnot(None),
            Subscription.expires_at < now,
        ).all()

        deactivated = 0
        for sub in expired:
            sub.is_active = False
            # Синхронизируем users.is_subscribed
            try:
                from uuid import UUID
                user_uuid = UUID(sub.user_id)
                user = db.query(User).filter(User.id == user_uuid).first()
            except Exception:
                user = None
            if user:
                user.is_subscribed = False
            deactivated += 1

        if deactivated:
            db.commit()
            logger.info(f"[Subscription] Деактивировано {deactivated} истёкших подписок")
        return deactivated
    except Exception as e:
        db.rollback()
        logger.error(f"[Subscription] Ошибка проверки истёкших подписок: {e}", exc_info=True)
        return 0
    finally:
        db.close()


