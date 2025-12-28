#!/usr/bin/env python3
"""
Скрипт для отслеживания генерации книги в реальном времени.
"""

import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from app.db import SessionLocal
from app.models import Book, Image, Scene
from uuid import UUID
import os

BOOK_ID = "8734aaf6-c0c7-4fb5-bc17-6ec68a0b9a76"

def get_status():
    """Получает текущий статус генерации."""
    db = SessionLocal()
    try:
        book_uuid = UUID(BOOK_ID)
        book = db.query(Book).filter(Book.id == book_uuid).first()
        if not book:
            return None
        
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        images = db.query(Image).filter(Image.book_id == book_uuid).all()
        
        scenes_with_prompts = len([s for s in scenes if s.image_prompt])
        draft_images = [img for img in images if img.draft_url]
        final_images = [img for img in images if img.final_url]
        
        return {
            "book_title": book.title,
            "status": book.status,
            "total_scenes": len(scenes),
            "scenes_with_prompts": scenes_with_prompts,
            "draft_images": len(draft_images),
            "final_images": len(final_images),
            "pdf_url": book.final_pdf_url,
            "draft_orders": [img.scene_order for img in draft_images],
            "final_orders": [img.scene_order for img in final_images]
        }
    finally:
        db.close()

def format_time(seconds):
    """Форматирует время в читаемый вид."""
    if seconds < 60:
        return f"{seconds}с"
    elif seconds < 3600:
        return f"{seconds//60}м {seconds%60}с"
    else:
        hours = seconds // 3600
        minutes = (seconds % 3600) // 60
        secs = seconds % 60
        return f"{hours}ч {minutes}м {secs}с"

def main():
    print("=" * 80)
    print("📚 МОНИТОРИНГ ГЕНЕРАЦИИ КНИГИ В РЕАЛЬНОМ ВРЕМЕНИ")
    print("=" * 80)
    print(f"Book ID: {BOOK_ID}")
    print("=" * 80)
    print()
    
    start_time = time.time()
    last_draft_count = 0
    last_final_count = 0
    
    try:
        while True:
            status = get_status()
            if not status:
                print("❌ Книга не найдена")
                break
            
            elapsed = int(time.time() - start_time)
            timestamp = time.strftime("%H:%M:%S")
            
            # Прогресс черновых изображений
            draft_progress = f"{status['draft_images']}/{status['scenes_with_prompts']}"
            draft_percent = (status['draft_images'] / status['scenes_with_prompts'] * 100) if status['scenes_with_prompts'] > 0 else 0
            
            # Прогресс финальных изображений
            final_progress = f"{status['final_images']}/{status['scenes_with_prompts']}"
            final_percent = (status['final_images'] / status['scenes_with_prompts'] * 100) if status['scenes_with_prompts'] > 0 else 0
            
            # Определяем текущий этап
            if status['pdf_url'] and status['pdf_url'] != 'None':
                stage = "✅ PDF создан"
            elif status['final_images'] > 0:
                stage = "🎨 Генерация финальных изображений"
            elif status['draft_images'] > 0:
                stage = "🖼️  Генерация черновых изображений"
            else:
                stage = "⏳ Ожидание начала генерации"
            
            # Выводим статус
            print(f"[{timestamp}] [{format_time(elapsed)}] {stage}")
            print(f"   📊 Черновые: {draft_progress} ({draft_percent:.1f}%) | Финальные: {final_progress} ({final_percent:.1f}%)")
            
            # Показываем новые изображения
            if status['draft_images'] > last_draft_count:
                new_drafts = status['draft_images'] - last_draft_count
                print(f"   ✅ Создано новых черновых изображений: +{new_drafts}")
                last_draft_count = status['draft_images']
            
            if status['final_images'] > last_final_count:
                new_finals = status['final_images'] - last_final_count
                print(f"   ✅ Создано новых финальных изображений: +{new_finals}")
                last_final_count = status['final_images']
            
            # Проверяем завершение
            if status['status'] == 'completed' and status['pdf_url'] and status['pdf_url'] != 'None':
                print()
                print("=" * 80)
                print("✅ ГЕНЕРАЦИЯ КНИГИ ЗАВЕРШЕНА УСПЕШНО!")
                print("=" * 80)
                print(f"📚 Название: {status['book_title']}")
                print(f"📄 PDF URL: {status['pdf_url']}")
                print(f"⏱️  Время генерации: {format_time(elapsed)}")
                print("=" * 80)
                break
            
            # Проверяем ошибку
            if status['status'] == 'error':
                print()
                print("=" * 80)
                print("❌ ГЕНЕРАЦИЯ ЗАВЕРШИЛАСЬ С ОШИБКОЙ")
                print("=" * 80)
                break
            
            time.sleep(3)
            
    except KeyboardInterrupt:
        print("\n\n⏸️  Мониторинг прерван пользователем")
    except Exception as e:
        print(f"\n\n❌ Ошибка мониторинга: {e}")

if __name__ == "__main__":
    main()

