import os
from fastapi import APIRouter

router = APIRouter(prefix="", tags=["auth"])

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")


@router.get("/auth_config")
def get_auth_config():
    """
    Возвращает конфигурацию Supabase для клиента
    """
    return {
        "supabase_url": SUPABASE_URL,
        "supabase_key": SUPABASE_KEY
    }

