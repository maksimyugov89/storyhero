"""
Скрипт для перегенерации промпта обложки БЕЗ упоминаний о тексте.
"""
import sys
sys.path.insert(0, '/app')

from app.db import SessionLocal
from app.models import Scene, Book
from app.services.gemini_service import generate_text
from uuid import UUID
import json
import re
import asyncio

async def main():
    db = SessionLocal()
    try:
        book_id = UUID('8734aaf6-c0c7-4fb5-bc17-6ec68a0b9a76')
        book = db.query(Book).filter(Book.id == book_id).first()
        cover_scene = db.query(Scene).filter(Scene.book_id == book_id, Scene.order == 0).first()
        
        if not cover_scene:
            print('❌ Обложка не найдена')
            return
        
        # Генерируем новый промпт БЕЗ упоминаний о тексте
        system_prompt = """Ты — эксперт по созданию визуальных описаний для детских книг.
Создавай яркие, детальные промпты для иллюстраций, которые передают настроение и действие сцены.
КРИТИЧЕСКИ ВАЖНО: 
1. В промпте НЕ должно быть НИКАКИХ упоминаний о тексте, названии, буквах, надписях.
2. Промпт должен описывать ТОЛЬКО визуальные элементы: персонажи, фон, цвета, композицию.
3. НИКАКОГО текста на изображении быть не должно!
Верни результат ТОЛЬКО в формате JSON, без дополнительного текста."""
        
        scene_text = cover_scene.short_summary or cover_scene.text or ''
        user_prompt = f"""Книга: {book.title}
Сцена обложки: {scene_text}

Создай промпт для иллюстрации обложки БЕЗ ТЕКСТА.
Промпт должен описывать ТОЛЬКО визуальные элементы: персонаж (5-летний ребенок Софья), фон (Калининград, собор, танцующий лес), цвета, стиль.
НИКАКИХ упоминаний о тексте, названии, буквах, надписях!

Формат JSON:
{{
  "prompt": "Book cover illustration. [описание БЕЗ текста]"
}}"""
        
        print('🔄 Генерация нового промпта для обложки БЕЗ текста...')
        response = await generate_text(user_prompt, system_prompt, json_mode=True)
        
        # Парсим JSON
        try:
            data = json.loads(response)
            new_prompt = data.get('prompt', '')
        except:
            # Если не JSON, пытаемся извлечь промпт
            match = re.search(r'"prompt"\s*:\s*"([^"]+)"', response)
            if match:
                new_prompt = match.group(1)
            else:
                new_prompt = response.strip()
        
        # Убеждаемся, что в промпте нет упоминаний о тексте
        forbidden_words = ['title', 'text', 'letters', 'written', 'drawn', 'name', 'название', 'текст', 'буквы', 'letter']
        for word in forbidden_words:
            if word.lower() in new_prompt.lower():
                print(f'⚠️ В промпте найдено слово "{word}", удаляю...')
                new_prompt = re.sub(rf'\b{word}\b[^.]*\.?\s*', '', new_prompt, flags=re.IGNORECASE)
        
        # Убираем двойные пробелы и точки
        new_prompt = re.sub(r'\s+', ' ', new_prompt)
        new_prompt = re.sub(r'\.\s*\.', '.', new_prompt)
        new_prompt = new_prompt.strip()
        
        # Убеждаемся, что промпт начинается правильно
        if not new_prompt.startswith('Book cover illustration'):
            new_prompt = 'Book cover illustration. ' + new_prompt
        
        cover_scene.image_prompt = new_prompt
        db.commit()
        print('✅ Новый промпт сохранен:')
        print(new_prompt)
        
    except Exception as e:
        print(f'❌ Ошибка: {e}', exc_info=True)
    finally:
        db.close()

if __name__ == "__main__":
    asyncio.run(main())

