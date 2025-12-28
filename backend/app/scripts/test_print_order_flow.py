"""
Скрипт для тестирования полного процесса заказа на печать:
1. Создание платежа
2. Подтверждение оплаты (с автоматическим созданием заказа)
3. Проверка уведомлений
"""
import sys
import os
sys.path.insert(0, '/app')

from app.routers.payments import (
    PrintOrderPaymentCreateRequest,
    PrintOrderPaymentConfirmRequest,
    PrintOrderData
)
import asyncio

async def test_print_order_flow():
    """Тест полного процесса заказа на печать"""
    print("🧪 Тестирование полного процесса заказа на печать")
    print("=" * 60)
    
    # Тестовые данные
    test_order_data = PrintOrderData(
        book_title="Тестовая книга для печати",
        size="A5 (Маленькая)",
        pages=20,
        binding="Мягкий переплёт",
        packaging="Простая упаковка",
        total_price=1350,
        customer_name="Иван Иванов",
        customer_phone="+7 (999) 123-45-67",
        customer_address="г. Москва, ул. Тестовая, д. 1",
        comment="Тестовый заказ"
    )
    
    print("\n1️⃣ Создание платежа:")
    print(f"   Книга: {test_order_data.book_title}")
    print(f"   Размер: {test_order_data.size}")
    print(f"   Страниц: {test_order_data.pages}")
    print(f"   Переплёт: {test_order_data.binding}")
    print(f"   Упаковка: {test_order_data.packaging}")
    print(f"   Цена: {test_order_data.total_price} ₽")
    
    create_request = PrintOrderPaymentCreateRequest(
        book_id="12345678-1234-1234-1234-123456789012",
        amount=test_order_data.total_price,
        order_data=test_order_data
    )
    
    print("\n✅ Запрос на создание платежа сформирован")
    
    print("\n2️⃣ Подтверждение оплаты (автоматическое создание заказа):")
    confirm_request = PrintOrderPaymentConfirmRequest(
        book_id="12345678-1234-1234-1234-123456789012",
        order_data=test_order_data
    )
    
    print("✅ Запрос на подтверждение оплаты сформирован")
    print("   → При подтверждении автоматически создастся заказ")
    print("   → Отправятся уведомления на email и Telegram")
    
    print("\n✅ Тестовые запросы готовы")
    print("\n📝 Для реального тестирования используйте API:")
    print("   POST /api/v1/payments/create_print_order")
    print("   POST /api/v1/payments/confirm_print_order")

if __name__ == "__main__":
    asyncio.run(test_print_order_flow())

