#!/usr/bin/env python3
"""
Скрипт для мониторинга генерации книги до полной готовности PDF.
"""
import sys
import time
from datetime import datetime

sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Book, Scene, Image
from sqlalchemy import desc


def get_book_status():
    """Получить статус последней книги."""
    db = SessionLocal()
    try:
        book = db.query(Book).order_by(desc(Book.created_at)).first()
        if not book:
            return None
        
        scenes = db.query(Scene).filter(Scene.book_id == book.id).count()
        draft_images = db.query(Image).filter(Image.book_id == book.id, Image.draft_url != None).count()
        final_images = db.query(Image).filter(Image.book_id == book.id, Image.final_url != None).count()
        
        return {
            "book": book,
            "scenes": scenes,
            "draft_images": draft_images,
            "final_images": final_images,
            "pdf_ready": book.final_pdf_url is not None
        }
    finally:
        db.close()


def print_status(status):
    """Вывести статус генерации."""
    book = status["book"]
    timestamp = datetime.now().strftime("%H:%M:%S")
    
    print(f"\n[{timestamp}] 📊 Статус генерации:")
    print(f"   📚 Книга: {book.title}")
    print(f"   📄 Статус книги: {book.status}")
    print(f"   🎬 Сцен: {status['scenes']}")
    print(f"   🖼️  Черновых изображений: {status['draft_images']}/{status['scenes']}")
    print(f"   ✨ Финальных изображений: {status['final_images']}/{status['scenes']}")
    
    if status['pdf_ready']:
        print(f"   ✅ PDF: ГОТОВ!")
        print(f"   📄 URL: {book.final_pdf_url}")
        print(f"   🌐 Полный URL: https://storyhero.ru{book.final_pdf_url if book.final_pdf_url.startswith('/') else '/' + book.final_pdf_url}")
    else:
        progress = 0
        if status['scenes'] > 0:
            # Прогресс: черновые (40%) + финальные (50%) + PDF (10%)
            draft_progress = (status['draft_images'] / status['scenes']) * 40
            final_progress = (status['final_images'] / status['scenes']) * 50
            progress = draft_progress + final_progress
        
        print(f"   ⏳ PDF: Генерируется... ({progress:.1f}%)")


def main():
    """Главная функция мониторинга."""
    print("=" * 70)
    print("🔍 МОНИТОРИНГ ГЕНЕРАЦИИ КНИГИ")
    print("=" * 70)
    print("⏳ Ожидание готовности PDF файла...")
    print("   (Проверка каждые 10 секунд)")
    print("=" * 70)
    
    last_draft_count = 0
    last_final_count = 0
    check_interval = 10  # секунд
    max_wait_time = 3600  # максимум 1 час
    start_time = time.time()
    
    while True:
        status = get_book_status()
        
        if not status:
            print("❌ Книга не найдена в БД")
            time.sleep(check_interval)
            continue
        
        # Выводим статус
        print_status(status)
        
        # Проверяем изменения
        if status['draft_images'] > last_draft_count:
            print(f"   🎉 Новое черновое изображение! ({status['draft_images']}/{status['scenes']})")
            last_draft_count = status['draft_images']
        
        if status['final_images'] > last_final_count:
            print(f"   🎉 Новое финальное изображение! ({status['final_images']}/{status['scenes']})")
            last_final_count = status['final_images']
        
        # Проверяем готовность PDF
        if status['pdf_ready']:
            print("\n" + "=" * 70)
            print("🎉 КНИГА ПОЛНОСТЬЮ ГОТОВА!")
            print("=" * 70)
            book = status["book"]
            print(f"📚 Название: {book.title}")
            print(f"📄 PDF URL: {book.final_pdf_url}")
            print(f"🌐 Полный URL: https://storyhero.ru{book.final_pdf_url if book.final_pdf_url.startswith('/') else '/' + book.final_pdf_url}")
            print("=" * 70)
            return 0
        
        # Проверяем таймаут
        elapsed = time.time() - start_time
        if elapsed > max_wait_time:
            print(f"\n⚠️ Превышено максимальное время ожидания ({max_wait_time} секунд)")
            print("   Генерация может продолжаться в фоновом режиме")
            return 1
        
        # Ждём перед следующей проверкой
        time.sleep(check_interval)


if __name__ == "__main__":
    try:
        exit_code = main()
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print("\n\n⚠️ Мониторинг прерван пользователем")
        sys.exit(1)
    except Exception as e:
        print(f"\n❌ Ошибка при мониторинге: {e}", exc_info=True)
        sys.exit(1)

