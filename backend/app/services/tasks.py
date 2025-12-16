import asyncio
import uuid
import logging
from typing import Dict, Any, Callable, Optional
from datetime import datetime

logger = logging.getLogger(__name__)

TASKS: Dict[str, Dict[str, Any]] = {}


def create_task(fn: Callable, *args, meta: Optional[Dict[str, Any]] = None, **kwargs) -> str:
    """
    Создать задачу и запустить её асинхронно
    
    Args:
        fn: Функция для выполнения
        *args, **kwargs: Аргументы функции
        meta: Метаданные задачи для проверки дубликатов
    
    Returns:
        task_id: ID задачи (или существующей, если найдена дублирующая)
    """
    # Проверяем, нет ли уже запущенной задачи с такими же метаданными
    if meta:
        existing_task_id = find_running_task(meta)
        if existing_task_id:
            logger.info(f"✓ Найдена уже запущенная задача {existing_task_id} для {meta}, возвращаем её ID.")
            return existing_task_id
    
    task_id = str(uuid.uuid4())
    
    TASKS[task_id] = {
        "status": "pending",
        "created_at": datetime.now().isoformat(),
        "result": None,
        "error": None,
        "meta": meta or {}
    }
    
    async def run_task():
        try:
            logger.info(f"🔄 Запуск задачи {task_id}")
            TASKS[task_id]["status"] = "running"
            if asyncio.iscoroutinefunction(fn):
                result = await fn(*args, **kwargs)
            else:
                result = fn(*args, **kwargs)
            logger.info(f"✅ Задача {task_id} успешно завершена")
            mark_completed(task_id, result)
        except Exception as e:
            # Извлекаем сообщение об ошибке
            if hasattr(e, 'detail'):
                # HTTPException имеет атрибут detail
                error_msg = str(e.detail)
            else:
                error_msg = str(e)
            
            logger.error(f"❌ Ошибка в задаче {task_id}: {error_msg}", exc_info=True)
            
            # Обновляем статус задачи на error
            if task_id in TASKS:
                TASKS[task_id]["status"] = "error"
                TASKS[task_id]["error"] = error_msg
                TASKS[task_id]["completed_at"] = datetime.now().isoformat()
                logger.info(f"✅ Задача {task_id} обновлена: status=error, error={error_msg[:100]}")
            else:
                logger.warning(f"⚠️ Задача {task_id} не найдена в TASKS при обработке ошибки")
    
    asyncio.create_task(run_task())
    
    return task_id


def get_task_status(task_id: str) -> Optional[Dict[str, Any]]:
    """
    Получить статус задачи
    
    Args:
        task_id: ID задачи
    
    Returns:
        Словарь со статусом задачи или None, если задача не найдена
    """
    return TASKS.get(task_id)


def find_running_task(meta: Dict[str, Any]) -> Optional[str]:
    """
    Найти задачу в статусе running с совпадающим meta
    (например, по user_id и child_id).
    """
    if not meta:
        return None
    for task_id, data in TASKS.items():
        if data.get("status") == "running" and data.get("meta") == meta:
            return task_id
    return None


def mark_completed(task_id: str, result: Any):
    """
    Отметить задачу как выполненную
    
    Args:
        task_id: ID задачи
        result: Результат выполнения
    """
    if task_id in TASKS:
        TASKS[task_id]["status"] = "success"  # Изменено: completed -> success для соответствия контракту
        TASKS[task_id]["result"] = result
        TASKS[task_id]["completed_at"] = datetime.now().isoformat()
        logger.info(f"✅ Задача {task_id} отмечена как успешно выполненная")

