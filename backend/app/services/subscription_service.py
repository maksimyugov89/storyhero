"""
Сервис для обслуживания подписок (деактивация истёкших и синхронизация флага users.is_subscribed)
"""

from datetime import datetime, timezone
import logging

from ..db import SessionLocal
from ..models import Subscription
from ..models.user import User

logger = logging.getLogger(__name__)


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


