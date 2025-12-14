"""
Единый модуль для работы с Supabase клиентом
"""
import os
import logging
from supabase import create_client, Client
from fastapi import HTTPException

logger = logging.getLogger(__name__)

# УДАЛЕНО: BUCKET_NAME больше не используется
# Вся загрузка файлов теперь происходит через локальное хранилище
# BUCKET_NAME = "children-photos"

# Глобальный клиент для операций с БД (использует service key)
_supabase_db_client: Client = None


def get_supabase_url() -> str:
    """Получить SUPABASE_URL"""
    url = os.getenv("SUPABASE_URL")
    if not url:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_URL не установлен в переменных окружения"
        )
    return url


def get_supabase_service_key() -> str:
    """Получить SUPABASE_SERVICE_KEY"""
    key = os.getenv("SUPABASE_SERVICE_KEY")
    if not key:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_SERVICE_KEY не установлен в переменных окружения"
        )
    return key


def get_supabase_key() -> str:
    """Получить SUPABASE_KEY (anon key)"""
    key = os.getenv("SUPABASE_KEY")
    if not key:
        raise HTTPException(
            status_code=500,
            detail="SUPABASE_KEY не установлен в переменных окружения"
        )
    return key


def get_supabase_client() -> Client:
    """
    Получить клиент Supabase для операций с БД (использует service key).
    Клиент кэшируется для переиспользования.
    """
    global _supabase_db_client
    
    if _supabase_db_client is None:
        try:
            supabase_url = get_supabase_url()
            supabase_service_key = get_supabase_service_key()
            
            _supabase_db_client = create_client(supabase_url, supabase_service_key)
            logger.info(f"✓ Supabase клиент инициализирован для URL: {supabase_url[:30]}...")
        except Exception as e:
            logger.error(f"✗ Ошибка при создании Supabase клиента: {str(e)}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=f"Не удалось создать Supabase клиент: {str(e)}"
            )
    
    return _supabase_db_client


def get_supabase_auth_client() -> Client:
    """Получить клиент Supabase для авторизации (использует anon key)"""
    try:
        supabase_url = get_supabase_url()
        supabase_key = get_supabase_key()
        client = create_client(supabase_url, supabase_key)
        logger.debug("✓ Supabase auth клиент создан")
        return client
    except Exception as e:
        logger.error(f"✗ Ошибка при создании Supabase auth клиента: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Не удалось создать Supabase auth клиент: {str(e)}"
        )


# УДАЛЕНО: Функции для работы с Supabase Storage больше не используются
# Вся загрузка файлов теперь происходит через локальное хранилище
# 
# def check_storage_bucket():
#     """Проверить существование bucket в Supabase Storage - больше не используется"""
#     ...
