"""
Тестовый роутер для проверки всех типов уведомлений (Email и Telegram)
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import Optional
import logging
import os

from ..core.deps import get_current_user
from .payments import (
    send_payment_notifications
)
from .support import (
    send_support_notifications
)
# Импортируем модуль payments для доступа к send_print_order_payment_notifications
from . import payments as payments_module
# Импортируем функцию отправки заказов
from .orders import send_order_notifications, PrintOrderCreate

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/test", tags=["test"])


class TestNotificationResponse(BaseModel):
    status: str
    message: str
    details: Optional[dict] = None


@router.post("/notifications/all", response_model=TestNotificationResponse)
async def test_all_notifications(
    current_user: dict = Depends(get_current_user)
):
    """
    Тестирование всех типов уведомлений:
    1. Оплата PDF файла
    2. Оплата заказа книги для печати
    3. Отправка сообщения об ошибке
    4. Отправка сообщения пожелания
    5. Отправка сообщения вопрос
    """
    user_id = current_user.get("sub") or current_user.get("id")
    user_email = current_user.get("email", "test@example.com")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    results = {
        "pdf_payment": {"status": "pending", "error": None},
        "print_order_payment": {"status": "pending", "error": None},
        "bug_report": {"status": "pending", "error": None},
        "suggestion": {"status": "pending", "error": None},
        "question": {"status": "pending", "error": None},
    }
    
    # 1. Тест оплаты PDF файла
    logger.info("[Test] 🧪 Тест 1: Оплата PDF файла")
    try:
        await send_payment_notifications(
            book_title="Тестовая книга PDF",
            book_id="test-pdf-123",
            user_email=user_email,
            pdf_url="https://example.com/test.pdf"
        )
        results["pdf_payment"]["status"] = "success"
        logger.info("[Test] ✅ Тест 1 успешен: Оплата PDF файла")
    except Exception as e:
        results["pdf_payment"]["status"] = "error"
        results["pdf_payment"]["error"] = str(e)
        logger.error(f"[Test] ❌ Тест 1 ошибка: {e}", exc_info=True)
    
    # 2. Тест оплаты заказа книги для печати
    logger.info("[Test] 🧪 Тест 2: Оплата заказа книги для печати")
    try:
        # Получаем функцию через getattr, так как она может быть не экспортирована
        send_print_order_payment_notifications = getattr(payments_module, 'send_print_order_payment_notifications', None)
        if not send_print_order_payment_notifications:
            raise AttributeError("Функция send_print_order_payment_notifications не найдена в модуле payments")
        await send_print_order_payment_notifications(
            book_title="Тестовая книга для печати",
            order_id="test-order-123",
            total_price=950,
            customer_name="Тестовый Клиент",
            customer_phone="+7 (999) 123-45-67",
            user_email=user_email,
            size="A5 (Маленькая)",
            pages=10,
            binding="Мягкий переплёт",
            packaging="Простая упаковка"
        )
        results["print_order_payment"]["status"] = "success"
        logger.info("[Test] ✅ Тест 2 успешен: Оплата заказа книги для печати")
    except Exception as e:
        results["print_order_payment"]["status"] = "error"
        results["print_order_payment"]["error"] = str(e)
        logger.error(f"[Test] ❌ Тест 2 ошибка: {e}", exc_info=True)
    
    # 3. Тест отправки сообщения об ошибке
    logger.info("[Test] 🧪 Тест 3: Отправка сообщения об ошибке")
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="bug",
            message="Это тестовое сообщение об ошибке. Приложение работает некорректно при генерации книги."
        )
        results["bug_report"]["status"] = "success"
        logger.info("[Test] ✅ Тест 3 успешен: Отправка сообщения об ошибке")
    except Exception as e:
        results["bug_report"]["status"] = "error"
        results["bug_report"]["error"] = str(e)
        logger.error(f"[Test] ❌ Тест 3 ошибка: {e}", exc_info=True)
    
    # 4. Тест отправки сообщения пожелания
    logger.info("[Test] 🧪 Тест 4: Отправка сообщения пожелания")
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="suggestion",
            message="Это тестовое пожелание. Хотелось бы добавить больше стилей для иллюстраций."
        )
        results["suggestion"]["status"] = "success"
        logger.info("[Test] ✅ Тест 4 успешен: Отправка сообщения пожелания")
    except Exception as e:
        results["suggestion"]["status"] = "error"
        results["suggestion"]["error"] = str(e)
        logger.error(f"[Test] ❌ Тест 4 ошибка: {e}", exc_info=True)
    
    # 5. Тест отправки сообщения вопрос
    logger.info("[Test] 🧪 Тест 5: Отправка сообщения вопрос")
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="question",
            message="Это тестовый вопрос. Как долго занимает генерация книги?"
        )
        results["question"]["status"] = "success"
        logger.info("[Test] ✅ Тест 5 успешен: Отправка сообщения вопрос")
    except Exception as e:
        results["question"]["status"] = "error"
        results["question"]["error"] = str(e)
        logger.error(f"[Test] ❌ Тест 5 ошибка: {e}", exc_info=True)
    
    # Подсчитываем результаты
    success_count = sum(1 for r in results.values() if r["status"] == "success")
    error_count = sum(1 for r in results.values() if r["status"] == "error")
    total_count = len(results)
    
    if error_count == 0:
        status = "success"
        message = f"✅ Все тесты пройдены успешно ({success_count}/{total_count})"
    else:
        status = "partial"
        message = f"⚠️ Тесты завершены с ошибками: успешно {success_count}/{total_count}, ошибок {error_count}"
    
    logger.info(f"[Test] 📊 Итоги тестирования: {message}")
    
    return TestNotificationResponse(
        status=status,
        message=message,
        details=results
    )


@router.post("/notifications/pdf", response_model=TestNotificationResponse)
async def test_pdf_payment_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест только уведомления об оплате PDF"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        await send_payment_notifications(
            book_title="Тестовая книга PDF",
            book_id="test-pdf-123",
            user_email=user_email,
            pdf_url="https://example.com/test.pdf"
        )
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление об оплате PDF отправлено"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )


@router.post("/notifications/print_order", response_model=TestNotificationResponse)
async def test_print_order_payment_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест только уведомления об оплате заказа на печать"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        send_print_order_payment_notifications = getattr(payments_module, 'send_print_order_payment_notifications', None)
        if not send_print_order_payment_notifications:
            raise AttributeError("Функция send_print_order_payment_notifications не найдена в модуле payments")
        await send_print_order_payment_notifications(
            book_title="Тестовая книга для печати",
            order_id="test-order-123",
            total_price=950,
            customer_name="Тестовый Клиент",
            customer_phone="+7 (999) 123-45-67",
            user_email=user_email,
            size="A5 (Маленькая)",
            pages=10,
            binding="Мягкий переплёт",
            packaging="Простая упаковка"
        )
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление об оплате заказа на печать отправлено"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )


@router.post("/notifications/bug", response_model=TestNotificationResponse)
async def test_bug_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест только уведомления об ошибке"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="bug",
            message="Это тестовое сообщение об ошибке."
        )
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление об ошибке отправлено"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )


@router.post("/notifications/suggestion", response_model=TestNotificationResponse)
async def test_suggestion_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест только уведомления пожелания"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="suggestion",
            message="Это тестовое пожелание."
        )
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление пожелания отправлено"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )


@router.post("/notifications/question", response_model=TestNotificationResponse)
async def test_question_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест только уведомления вопроса"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        await send_support_notifications(
            name="Тестовый Пользователь",
            email=user_email,
            message_type="question",
            message="Это тестовый вопрос."
        )
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление вопроса отправлено"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )


@router.post("/notifications/print_order", response_model=TestNotificationResponse)
async def test_print_order_notification(
    current_user: dict = Depends(get_current_user)
):
    """Тест уведомления о заказе на печать с полным сообщением и PDF"""
    user_email = current_user.get("email", "test@example.com")
    
    try:
        # Создаем тестовый заказ
        test_order = PrintOrderCreate(
            book_id="test-book-123",
            book_title="Тестовая книга для печати",
            size="A5 (Маленькая)",
            pages=10,
            binding="Мягкий переплёт",
            packaging="Простая упаковка",
            total_price=950,
            customer_name="Тестовый Клиент",
            customer_phone="+7 (999) 123-45-67",
            customer_address="Тестовый адрес, д. 1, кв. 1, индекс-123456",
            comment="Тестовый комментарий к заказу"
        )
        
        # Отправляем уведомление
        await send_order_notifications(
            order=test_order,
            order_id="test-order-123",
            user_email=user_email,
            db=None  # Будет создана новая сессия
        )
        
        return TestNotificationResponse(
            status="success",
            message="✅ Уведомление о заказе на печать отправлено (с полным сообщением и PDF)"
        )
    except Exception as e:
        logger.error(f"[Test] Ошибка: {e}", exc_info=True)
        import traceback
        traceback.print_exc()
        return TestNotificationResponse(
            status="error",
            message=f"❌ Ошибка отправки: {str(e)}"
        )

