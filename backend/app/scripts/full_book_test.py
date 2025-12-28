#!/usr/bin/env python3
"""
Полный прогон создания книги с токеном и child_id из логов.
Исправляет ошибки по мере их возникновения до создания финального PDF.
"""

import sys
import asyncio
import json
from pathlib import Path

# Добавляем корень проекта в путь
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

import httpx
from dotenv import load_dotenv
import os

# Загружаем переменные окружения
load_dotenv()

# Данные из логов
TOKEN = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiI0NDQ1ZTJkMi0zYjNkLTQ1NTItODQ3Yy1hNzkyN2I0NGY5NDQiLCJlbWFpbCI6ImRlc3BhZC44OUBtYWlsLnJ1IiwiZXhwIjoxNzY4Njk1MDU1LCJpYXQiOjE3NjYxMDMwNTV9.3STyOqOdZFnl2aJcu6No3lpnBEo8P1glVPsDGcS5Th0"
CHILD_ID = "1"
BASE_URL = os.getenv("BASE_URL", "https://storyhero.ru/api/v1")

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}


async def check_task_status(task_id: str, client: httpx.AsyncClient) -> dict:
    """Проверяет статус задачи с polling."""
    max_wait = 600  # 10 минут максимум
    wait_time = 0
    poll_interval = 3
    
    while wait_time < max_wait:
        resp = await client.get(f"{BASE_URL}/books/task_status/{task_id}", headers=headers)
        if resp.status_code != 200:
            print(f"❌ Ошибка проверки статуса: {resp.status_code} - {resp.text}")
            return {"status": "error", "error": resp.text}
        
        data = resp.json()
        status = data.get("status")
        stage = data.get("stage", "")
        message = data.get("message", "")
        
        print(f"📊 [{wait_time}s] Статус: {status}, Этап: {stage}, Сообщение: {message}")
        
        if status == "completed":
            print(f"✅ Задача завершена успешно!")
            return data
        elif status == "error":
            error = data.get("error", "Неизвестная ошибка")
            print(f"❌ Задача завершилась с ошибкой: {error}")
            return data
        
        await asyncio.sleep(poll_interval)
        wait_time += poll_interval
    
    print(f"⏱️ Превышено время ожидания ({max_wait}s)")
    return {"status": "timeout"}


async def generate_full_book(client: httpx.AsyncClient) -> dict:
    """Запускает генерацию полной книги."""
    print(f"\n🚀 Запуск генерации книги для child_id={CHILD_ID}...")
    
    payload = {
        "child_id": CHILD_ID,
        "style": "fairytale",
        "num_pages": 10
    }
    
    resp = await client.post(f"{BASE_URL}/books/generate_full_book", json=payload, headers=headers)
    
    if resp.status_code != 200:
        print(f"❌ Ошибка запуска генерации: {resp.status_code} - {resp.text}")
        return {"error": resp.text}
    
    data = resp.json()
    task_id = data.get("task_id")
    print(f"✅ Задача создана: task_id={task_id}")
    
    return await check_task_status(task_id, client)


async def get_book_id_from_task(task_result: dict) -> str:
    """Извлекает book_id из результата задачи."""
    book_id = task_result.get("book_id")
    if not book_id:
        # Пробуем получить из прогресса
        progress = task_result.get("progress", {})
        book_id = progress.get("book_id")
    return book_id


async def finalize_book(book_id: str, client: httpx.AsyncClient) -> dict:
    """Финализирует книгу и создаёт PDF."""
    print(f"\n📚 Финализация книги book_id={book_id}...")
    
    # Шаг 1: Выбор изображений
    print("  → Выбор изображений...")
    select_payload = {"selected_images": []}  # Пустой список = использовать все
    resp = await client.post(
        f"{BASE_URL}/books/{book_id}/finalize/select",
        json=select_payload,
        headers=headers
    )
    
    if resp.status_code != 200:
        print(f"❌ Ошибка выбора изображений: {resp.status_code} - {resp.text}")
        return {"error": resp.text}
    
    print("  ✅ Изображения выбраны")
    
    # Шаг 2: Рендеринг PDF
    print("  → Рендеринг PDF...")
    render_payload = {}
    resp = await client.post(
        f"{BASE_URL}/books/{book_id}/finalize/render",
        json=render_payload,
        headers=headers
    )
    
    if resp.status_code != 200:
        print(f"❌ Ошибка рендеринга PDF: {resp.status_code} - {resp.text}")
        return {"error": resp.text}
    
    data = resp.json()
    pdf_url = data.get("pdf_url")
    print(f"  ✅ PDF создан: {pdf_url}")
    
    return data


async def main():
    """Главная функция."""
    print("=" * 80)
    print("ПОЛНЫЙ ПРОГОН СОЗДАНИЯ КНИГИ")
    print("=" * 80)
    print(f"BASE_URL: {BASE_URL}")
    print(f"CHILD_ID: {CHILD_ID}")
    print("=" * 80)
    
    async with httpx.AsyncClient(timeout=300.0) as client:
        # Шаг 1: Генерация книги
        task_result = await generate_full_book(client)
        
        if task_result.get("status") != "completed":
            print(f"\n❌ Генерация книги не завершилась успешно")
            print(f"Результат: {json.dumps(task_result, indent=2, ensure_ascii=False)}")
            return 1
        
        book_id = await get_book_id_from_task(task_result)
        if not book_id:
            print(f"\n❌ Не удалось получить book_id из результата задачи")
            print(f"Результат: {json.dumps(task_result, indent=2, ensure_ascii=False)}")
            return 1
        
        print(f"\n✅ Книга создана: book_id={book_id}")
        
        # Шаг 2: Финализация и PDF
        pdf_result = await finalize_book(book_id, client)
        
        if "error" in pdf_result:
            print(f"\n❌ Ошибка при создании PDF")
            return 1
        
        print("\n" + "=" * 80)
        print("✅ ПОЛНЫЙ ПРОГОН ЗАВЕРШЁН УСПЕШНО!")
        print("=" * 80)
        print(f"PDF URL: {pdf_result.get('pdf_url', 'N/A')}")
        print("=" * 80)
        
        return 0


if __name__ == "__main__":
    exit_code = asyncio.run(main())
    sys.exit(exit_code)

