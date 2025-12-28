#!/usr/bin/env python3
"""
Скрипт для запуска генерации книги через API с токеном из логов.
"""

import asyncio
import httpx
import json
import time

# Данные из логов
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiJiOGRhZjFjYi05MGZiLTQwMTEtYWVkZC1mN2Q5ZjBjNmZmYmMiLCJlbWFpbCI6ImRlc3BhZC44OUBtYWlsLnJ1IiwiZXhwIjoxNzY5MDk5NTEzLCJpYXQiOjE3NjY1MDc1MTN9.Rmmh0lmF31vbOmRq0UmIxtQMEpw7nvxd1jbaTXwMfwc"
CHILD_ID = "1"
BASE_URL = "https://storyhero.ru/api/v1"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}


async def check_task_status(task_id: str, client: httpx.AsyncClient) -> dict:
    """Проверяет статус задачи с polling."""
    max_wait = 3600  # 1 час максимум
    wait_time = 0
    poll_interval = 5
    
    print(f"\n📊 Отслеживание прогресса задачи {task_id}...")
    print("=" * 80)
    
    while wait_time < max_wait:
        try:
            resp = await client.get(f"{BASE_URL}/books/task_status/{task_id}", headers=headers, timeout=30.0)
            if resp.status_code != 200:
                print(f"❌ Ошибка проверки статуса: {resp.status_code} - {resp.text}")
                await asyncio.sleep(poll_interval)
                wait_time += poll_interval
                continue
            
            data = resp.json()
            status = data.get("status")
            progress = data.get("progress", {})
            stage = progress.get("stage", "")
            message = progress.get("message", "")
            current_step = progress.get("current_step", 0)
            total_steps = progress.get("total_steps", 0)
            
            print(f"⏱️  [{wait_time:4d}s] Статус: {status:10s} | Этап: {stage:25s} | Шаг: {current_step}/{total_steps}")
            if message:
                print(f"   💬 {message}")
            
            if status == "completed":
                print("\n" + "=" * 80)
                print("✅ Задача завершена успешно!")
                print("=" * 80)
                return data
            elif status == "error":
                error = data.get("error", "Неизвестная ошибка")
                print("\n" + "=" * 80)
                print(f"❌ Задача завершилась с ошибкой: {error}")
                print("=" * 80)
                return data
            
            await asyncio.sleep(poll_interval)
            wait_time += poll_interval
        except Exception as e:
            print(f"⚠️  Ошибка при проверке статуса: {e}")
            await asyncio.sleep(poll_interval)
            wait_time += poll_interval
    
    print(f"\n⏱️  Превышено время ожидания ({max_wait}s)")
    return {"status": "timeout"}


async def generate_full_book(client: httpx.AsyncClient) -> dict:
    """Запускает генерацию полной книги."""
    print(f"\n🚀 Запуск генерации книги для child_id={CHILD_ID}...")
    print("=" * 80)
    
    payload = {
        "child_id": CHILD_ID,
        "style": "watercolor",
        "num_pages": 10,
        "theme": "про поездку в город Калининград"
    }
    
    print(f"📋 Параметры:")
    print(f"   - Child ID: {CHILD_ID}")
    print(f"   - Стиль: {payload['style']}")
    print(f"   - Страниц: {payload['num_pages']}")
    print(f"   - Тема: {payload['theme']}")
    print("=" * 80)
    
    try:
        resp = await client.post(
            f"{BASE_URL}/books/generate_full_book",
            json=payload,
            headers=headers,
            timeout=30.0
        )
        
        if resp.status_code != 200:
            print(f"❌ Ошибка запуска генерации: {resp.status_code}")
            print(f"   Ответ: {resp.text}")
            return {"error": resp.text}
        
        data = resp.json()
        task_id = data.get("task_id")
        print(f"✅ Задача создана: task_id={task_id}")
        
        return await check_task_status(task_id, client)
    except Exception as e:
        print(f"❌ Ошибка при запуске генерации: {e}")
        return {"error": str(e)}


async def main():
    """Главная функция."""
    print("=" * 80)
    print("📚 ГЕНЕРАЦИЯ КНИГИ ДО СОЗДАНИЯ PDF")
    print("=" * 80)
    print(f"BASE_URL: {BASE_URL}")
    print(f"CHILD_ID: {CHILD_ID}")
    print("=" * 80)
    
    async with httpx.AsyncClient(timeout=300.0) as client:
        result = await generate_full_book(client)
        
        if result.get("status") == "completed":
            print("\n" + "=" * 80)
            print("✅ ГЕНЕРАЦИЯ КНИГИ ЗАВЕРШЕНА УСПЕШНО!")
            print("=" * 80)
            
            progress = result.get("progress", {})
            book_id = progress.get("book_id") or result.get("book_id")
            pdf_url = progress.get("pdf_url") or result.get("pdf_url")
            
            if book_id:
                print(f"📚 Book ID: {book_id}")
            if pdf_url:
                print(f"📄 PDF URL: {pdf_url}")
            
            print("=" * 80)
            return 0
        else:
            print("\n" + "=" * 80)
            print("❌ ГЕНЕРАЦИЯ КНИГИ НЕ ЗАВЕРШИЛАСЬ УСПЕШНО")
            print("=" * 80)
            print(f"Результат: {json.dumps(result, indent=2, ensure_ascii=False)}")
            print("=" * 80)
            return 1


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    exit(exit_code)

