"""
Скрипт для тестирования уведомлений о покупке PDF книги
"""
import sys
import os
sys.path.insert(0, '/app')

from app.routers.payments import send_payment_notifications
import asyncio

async def test_pdf_payment():
    """Тест отправки уведомлений о покупке PDF"""
    print("🧪 Тестирование уведомлений о покупке PDF книги")
    print("=" * 60)
    
    await send_payment_notifications(
        book_title="Тестовая книга для проверки уведомлений",
        book_id="12345678-1234-1234-1234-123456789012",
        user_email="test@example.com",
        pdf_url="https://storyhero.ru/static/books/test.pdf"
    )
    
    print("\n✅ Уведомления отправлены (или пропущены, если нет конфигурации)")
    print("Проверьте логи бэкенда и почту/Telegram")

if __name__ == "__main__":
    asyncio.run(test_pdf_payment())

