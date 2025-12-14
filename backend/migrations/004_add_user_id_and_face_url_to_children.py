#!/usr/bin/env python3
"""
Миграция: Добавление полей user_id и face_url в таблицу children
Выполнить: python migrations/004_add_user_id_and_face_url_to_children.py
"""
import os
import sys
from sqlalchemy import create_engine, text

# Получаем DATABASE_URL из переменных окружения
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://storyhero:storyhero_pass@127.0.0.1:5432/storyhero_db",
)

def run_migration():
    """Выполняет миграцию для добавления полей user_id и face_url"""
    engine = create_engine(DATABASE_URL)
    
    with engine.connect() as conn:
        # Начинаем транзакцию
        trans = conn.begin()
        try:
            # Добавляем колонку user_id, если её нет
            print("Добавление колонки user_id...")
            conn.execute(text("""
                ALTER TABLE children 
                ADD COLUMN IF NOT EXISTS user_id VARCHAR;
            """))
            
            # Добавляем колонку face_url, если её нет
            print("Добавление колонки face_url...")
            conn.execute(text("""
                ALTER TABLE children 
                ADD COLUMN IF NOT EXISTS face_url VARCHAR;
            """))
            
            # Коммитим транзакцию
            trans.commit()
            print("✓ Миграция успешно выполнена!")
            
        except Exception as e:
            trans.rollback()
            print(f"✗ Ошибка при выполнении миграции: {e}")
            sys.exit(1)

if __name__ == "__main__":
    run_migration()

