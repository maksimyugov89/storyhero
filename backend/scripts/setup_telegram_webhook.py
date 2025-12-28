#!/usr/bin/env python3
"""
Скрипт для настройки Telegram webhook для системы поддержки.

Использование:
    python scripts/setup_telegram_webhook.py

Или с параметрами:
    python scripts/setup_telegram_webhook.py --url https://storyhero.ru/api/v1/support/telegram/webhook --secret YOUR_SECRET_TOKEN
"""
import os
import sys
import argparse
import httpx
from pathlib import Path

# Добавляем путь к приложению
sys.path.insert(0, str(Path(__file__).parent.parent))

def load_env_file(env_path):
    """Простая загрузка .env файла"""
    try:
        if Path(env_path).exists():
            with open(env_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        if key:
                            os.environ[key] = value
            return True
    except Exception as e:
        print(f"⚠ Ошибка при загрузке .env: {e}")
    return False

# Загружаем .env файл
for env_path in ["/app/.env", "/app/backend/.env", ".env", "backend/.env"]:
    if load_env_file(env_path):
        print(f"✓ Загружены переменные из {env_path}")
        break

def setup_webhook(bot_token: str, webhook_url: str, secret_token: str = None):
    """Настроить webhook для Telegram бота"""
    url = f"https://api.telegram.org/bot{bot_token}/setWebhook"
    
    params = {
        "url": webhook_url
    }
    
    if secret_token:
        params["secret_token"] = secret_token
        print(f"🔐 Используется секретный токен для безопасности")
    
    try:
        response = httpx.post(url, json=params, timeout=10.0)
        data = response.json()
        
        if data.get("ok"):
            print(f"✅ Webhook успешно настроен!")
            print(f"   URL: {webhook_url}")
            if secret_token:
                print(f"   Секретный токен: установлен")
            return True
        else:
            error_msg = data.get("description", "Unknown error")
            print(f"❌ Ошибка настройки webhook: {error_msg}")
            return False
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        return False

def get_webhook_info(bot_token: str):
    """Получить информацию о текущем webhook"""
    url = f"https://api.telegram.org/bot{bot_token}/getWebhookInfo"
    
    try:
        response = httpx.get(url, timeout=10.0)
        data = response.json()
        
        if data.get("ok"):
            webhook_info = data.get("result", {})
            print(f"\n📋 Информация о webhook:")
            print(f"   URL: {webhook_info.get('url', 'не установлен')}")
            print(f"   Ожидает обновления: {webhook_info.get('pending_update_count', 0)}")
            print(f"   Последняя ошибка: {webhook_info.get('last_error_message', 'нет')}")
            print(f"   Последняя ошибка (дата): {webhook_info.get('last_error_date', 'нет')}")
            return webhook_info
        else:
            print(f"❌ Ошибка получения информации: {data.get('description', 'Unknown error')}")
            return None
    except Exception as e:
        print(f"❌ Ошибка: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Настройка Telegram webhook для системы поддержки")
    parser.add_argument(
        "--url",
        type=str,
        default=None,
        help="URL для webhook (например, https://storyhero.ru/api/v1/support/telegram/webhook)"
    )
    parser.add_argument(
        "--secret",
        type=str,
        default=None,
        help="Секретный токен для безопасности (опционально)"
    )
    parser.add_argument(
        "--info",
        action="store_true",
        help="Только показать информацию о текущем webhook"
    )
    
    args = parser.parse_args()
    
    # Получаем токен бота
    bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
    if not bot_token:
        print("❌ Ошибка: TELEGRAM_BOT_TOKEN не установлен в переменных окружения")
        print("   Установите его в .env файле или через переменные окружения")
        sys.exit(1)
    
    # Если только информация
    if args.info:
        get_webhook_info(bot_token)
        return
    
    # Получаем URL webhook
    webhook_url = args.url
    if not webhook_url:
        # Пробуем получить из переменных окружения
        webhook_url = os.getenv("TELEGRAM_WEBHOOK_URL")
        if not webhook_url:
            print("❌ Ошибка: URL webhook не указан")
            print("   Используйте --url или установите TELEGRAM_WEBHOOK_URL в .env")
            sys.exit(1)
    
    # Получаем секретный токен
    secret_token = args.secret or os.getenv("TELEGRAM_WEBHOOK_SECRET")
    
    print(f"🔧 Настройка Telegram webhook...")
    print(f"   Bot Token: {bot_token[:10]}...")
    print(f"   Webhook URL: {webhook_url}")
    
    # Показываем текущую информацию
    print(f"\n📋 Текущее состояние webhook:")
    get_webhook_info(bot_token)
    
    # Настраиваем webhook
    print(f"\n🔧 Настройка нового webhook...")
    if setup_webhook(bot_token, webhook_url, secret_token):
        print(f"\n✅ Готово! Проверяем результат...")
        get_webhook_info(bot_token)
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()

