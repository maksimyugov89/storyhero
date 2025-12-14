"""
Модуль storage.py - для обратной совместимости
Теперь использует локальное хранилище вместо Supabase Storage
"""
import os
import logging
from supabase import Client
from fastapi import HTTPException

# Импортируем функции из нового модуля
from ..supabase_client import (
    get_supabase_client as _get_supabase_client,
    get_supabase_auth_client as _get_supabase_auth_client,
)

logger = logging.getLogger(__name__)


def get_supabase_url():
    """Получить SUPABASE_URL (читаем динамически)"""
    return os.getenv("SUPABASE_URL")

def get_supabase_key():
    """Получить SUPABASE_KEY (читаем динамически)"""
    return os.getenv("SUPABASE_KEY")  # Для auth

def get_supabase_service_key():
    """Получить SUPABASE_SERVICE_KEY (читаем динамически)"""
    return os.getenv("SUPABASE_SERVICE_KEY")  # Для операций с БД


def get_supabase_client() -> Client:
    """Получить клиент Supabase для операций с БД (использует service key)"""
    return _get_supabase_client()


def get_supabase_auth_client() -> Client:
    """Получить клиент Supabase для авторизации (использует anon key)"""
    return _get_supabase_auth_client()


def upload_image(file_bytes: bytes, path: str, content_type: str = "image/jpeg") -> str:
    """
    Загрузить изображение в локальное хранилище
    
    DEPRECATED: Используйте upload_image_bytes из local_file_service напрямую
    
    Args:
        file_bytes: Байты изображения
        path: Относительный путь для сохранения (например, "final/uuid.jpg" или "drafts/uuid.jpg")
        content_type: MIME тип файла (по умолчанию image/jpeg)
    
    Returns:
        str: Публичный URL изображения
    
    Raises:
        HTTPException: Если загрузка не удалась
    """
    from .local_file_service import upload_image_bytes
    
    try:
        # Используем новый локальный сервис
        return upload_image_bytes(file_bytes, path, content_type)
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"✗ Ошибка при загрузке изображения: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Непредвиденная ошибка при загрузке изображения: {str(e)}"
        )


def init_children_table():
    """
    Создать таблицу children в Supabase через service_role, если её нет.
    
    Таблица создаётся с точными полями:
    - id uuid primary key default uuid_generate_v4()
    - name text
    - age int
    - interests text
    - fears text
    - character text
    - moral text
    - face_url text (опционально, для URL фотографии)
    - created_at timestamp default now()
    """
    import os
    from sqlalchemy import create_engine, text as sql_text
    
    try:
        # Пробуем использовать прямое подключение к PostgreSQL через DATABASE_URL
        # Это работает, если DATABASE_URL указывает на ту же БД, что и Supabase
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            try:
                engine = create_engine(database_url)
                with engine.begin() as conn:
                    # Проверяем, существует ли таблица
                    check_sql = sql_text("""
                        SELECT EXISTS (
                            SELECT FROM information_schema.tables 
                            WHERE table_schema = 'public' 
                            AND table_name = 'children'
                        );
                    """)
                    result = conn.execute(check_sql)
                    table_exists = result.scalar()
                    
                    if not table_exists:
                        # Создаём таблицу с ТОЧНО указанными полями
                        create_sql = sql_text("""
                            CREATE TABLE IF NOT EXISTS children (
                                id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
                                name text,
                                age int,
                                interests text,
                                fears text,
                                character text,
                                moral text,
                                face_url text,
                                created_at timestamp DEFAULT now()
                            );
                        """)
                        conn.execute(create_sql)
                        print("✓ Таблица children успешно создана в Supabase")
                    else:
                        # Проверяем, есть ли поле face_url, если нет - добавляем
                        check_face_url_sql = sql_text("""
                            SELECT EXISTS (
                                SELECT FROM information_schema.columns 
                                WHERE table_schema = 'public' 
                                AND table_name = 'children' 
                                AND column_name = 'face_url'
                            );
                        """)
                        result = conn.execute(check_face_url_sql)
                        face_url_exists = result.scalar()
                        
                        if not face_url_exists:
                            add_face_url_sql = sql_text("""
                                ALTER TABLE children ADD COLUMN IF NOT EXISTS face_url text;
                            """)
                            conn.execute(add_face_url_sql)
                            print("✓ Поле face_url добавлено в таблицу children")
                        print("✓ Таблица children уже существует в Supabase")
                return
            except Exception as e:
                print(f"⚠ Не удалось создать таблицу через DATABASE_URL: {str(e)}")
                print("   Пробуем альтернативный способ...")
        
        # Альтернативный способ: проверяем через Supabase client с service_role
        try:
            supabase = get_supabase_client()
            # Пробуем сделать select - если таблица существует, запрос пройдёт
            supabase.table("children").select("id").limit(1).execute()
            print("✓ Таблица children уже существует в Supabase (проверено через client)")
        except Exception as table_error:
            # Если таблицы нет, выводим инструкцию для ручного создания
            print("⚠ ВНИМАНИЕ: Таблица children не найдена в Supabase.")
            print("   Создайте таблицу вручную через SQL Editor в Supabase Dashboard:")
            print("   " + "="*60)
            print("""
CREATE TABLE IF NOT EXISTS children (
    id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    name text,
    age int,
    interests text,
    fears text,
    character text,
    moral text,
    face_url text,
    created_at timestamp DEFAULT now()
);
            """)
            print("   " + "="*60)
            print(f"   Ошибка при проверке: {str(table_error)}")
    except Exception as e:
        print(f"⚠ Предупреждение при инициализации таблицы children: {str(e)}")
        print("   Убедитесь, что таблица создана вручную в Supabase Dashboard")
