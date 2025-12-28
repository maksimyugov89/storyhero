#!/usr/bin/env python3
"""
Скрипт для проверки прогресса исправления обложек.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from app.db import SessionLocal
from app.models import Book, Scene, Image

db = SessionLocal()
try:
    # Книги БЕЗ финальных обложек
    books_without_final = db.query(Book).join(Scene).filter(
        Scene.order == 0,
        Scene.image_prompt.isnot(None),
        Scene.image_prompt != ''
    ).outerjoin(Image, (Image.book_id == Book.id) & (Image.scene_order == 0)).filter(
        (Image.final_url.is_(None)) | (Image.final_url == '')
    ).distinct().all()
    
    # Книги С финальными обложками
    books_with_final = db.query(Book).join(Scene).join(Image).filter(
        Scene.order == 0,
        Scene.image_prompt.isnot(None),
        Scene.image_prompt != '',
        Image.scene_order == 0,
        Image.final_url.isnot(None),
        Image.final_url != ''
    ).distinct().all()
    
    total_books = len(books_without_final) + len(books_with_final)
    
    print(f"📊 ПРОГРЕСС ИСПРАВЛЕНИЯ ОБЛОЖЕК")
    print(f"{'='*60}")
    print(f"📚 Книг БЕЗ финальных обложек: {len(books_without_final)}")
    print(f"📚 Книг С финальными обложками: {len(books_with_final)}")
    print(f"📚 Всего книг: {total_books}")
    print(f"{'='*60}")
    
    if len(books_without_final) > 0:
        print(f"\n⚠️ Осталось обработать {len(books_without_final)} книг без финальных обложек")
        progress = ((total_books - len(books_without_final)) / total_books) * 100
        print(f"📈 Прогресс: {progress:.1f}%")
    else:
        print(f"\n✅ Все книги имеют финальные обложки!")
        
finally:
    db.close()

