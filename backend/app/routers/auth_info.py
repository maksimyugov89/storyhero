import os
from fastapi import APIRouter

router = APIRouter(prefix="", tags=["auth"])


@router.get("/auth_config")
def get_auth_config():
    """
    Возвращает конфигурацию для клиента
    """
    return {
    }
