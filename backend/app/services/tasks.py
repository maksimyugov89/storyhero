import asyncio
import uuid
import logging
from typing import Dict, Any, Callable, Optional
from datetime import datetime, timedelta

logger = logging.getLogger(__name__)

TASKS: Dict[str, Dict[str, Any]] = {}

# Максимальное время выполнения задачи (30 минут)
MAX_TASK_DURATION = timedelta(minutes=30)


def update_task_progress(task_id: str, progress: Dict[str, Any]):
    """
    Обновить прогресс задачи
    
    Args:
        task_id: ID задачи
        progress: Словарь с информацией о прогрессе:
            - stage: текущий этап (text_ready, generating_images, images_ready, completed)
            - current_step: номер текущего шага
            - total_steps: общее количество шагов
            - images_generated: количество сгенерированных изображений
            - total_images: общее количество изображений
            - message: сообщение для пользователя
            - book_id: ID книги (если известен)
    """
    if task_id in TASKS:
        if "progress" not in TASKS[task_id]:
            TASKS[task_id]["progress"] = {}
        TASKS[task_id]["progress"].update(progress)
        TASKS[task_id]["progress"]["updated_at"] = datetime.now().isoformat()
        logger.info(f"📊 Прогресс задачи {task_id} обновлен: {progress}")


def create_task(fn: Callable, *args, meta: Optional[Dict[str, Any]] = None, task_id: Optional[str] = None, **kwargs) -> str:
    """
    Создать задачу и запустить её асинхронно
    
    ⚠️ ВАЖНО: Задачи хранятся в памяти и теряются при перезапуске контейнера!
    Не перезапускайте контейнер во время генерации книги!
    
    Args:
        fn: Функция для выполнения
        *args, **kwargs: Аргументы функции
        meta: Метаданные задачи для проверки дубликатов
        task_id: Опциональный ID задачи (если не указан, генерируется новый)
    
    Returns:
        task_id: ID задачи (или существующей, если найдена дублирующая)
    """
    # Проверяем, нет ли уже запущенной задачи с такими же метаданными
    if meta:
        existing_task_id = find_running_task(meta)
        if existing_task_id:
            logger.info(f"✓ Найдена уже запущенная задача {existing_task_id} для {meta}, возвращаем её ID.")
            return existing_task_id
    
    if not task_id:
        task_id = str(uuid.uuid4())
    
    TASKS[task_id] = {
        "status": "pending",
        "created_at": datetime.now().isoformat(),
        "result": None,
        "error": None,
        "meta": meta or {},
        "progress": {
            "stage": "starting",
            "current_step": 0,
            "total_steps": 7,
            "message": "Инициализация генерации книги..."
        }
    }
    
    logger.warning(f"⚠️  ВАЖНО: Задача {task_id} создана. Не перезапускайте контейнер до завершения генерации!")
    
    async def run_task():
        try:
            logger.info(f"🔄 Запуск задачи {task_id}")
            TASKS[task_id]["status"] = "running"
            TASKS[task_id]["started_at"] = datetime.now().isoformat()
            
            # Создаем таймаут для задачи
            try:
                # Передаем task_id в функцию, если она принимает этот параметр
                if asyncio.iscoroutinefunction(fn):
                    # Проверяем, принимает ли функция task_id
                    import inspect
                    sig = inspect.signature(fn)
                    if 'task_id' in sig.parameters:
                        result = await asyncio.wait_for(
                            fn(*args, task_id=task_id, **kwargs),
                            timeout=MAX_TASK_DURATION.total_seconds()
                        )
                    else:
                        result = await asyncio.wait_for(
                            fn(*args, **kwargs),
                            timeout=MAX_TASK_DURATION.total_seconds()
                        )
                else:
                    import inspect
                    sig = inspect.signature(fn)
                    if 'task_id' in sig.parameters:
                        result = fn(*args, task_id=task_id, **kwargs)
                    else:
                        result = fn(*args, **kwargs)
                
                logger.info(f"✅ Задача {task_id} успешно завершена")
                mark_completed(task_id, result)
            except asyncio.TimeoutError:
                error_msg = f"Задача превысила максимальное время выполнения ({MAX_TASK_DURATION.total_seconds() / 60:.0f} минут)"
                logger.error(f"⏱️ Таймаут задачи {task_id}: {error_msg}")
                if task_id in TASKS:
                    TASKS[task_id]["status"] = "error"
                    TASKS[task_id]["error"] = error_msg
                    TASKS[task_id]["completed_at"] = datetime.now().isoformat()
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
    Также проверяет, не превысила ли задача максимальное время выполнения.
    """
    if not meta:
        return None
    for task_id, data in TASKS.items():
        if data.get("status") == "running" and data.get("meta") == meta:
            # Проверяем, не превысила ли задача максимальное время выполнения
            started_at_str = data.get("started_at")
            if started_at_str:
                try:
                    started_at = datetime.fromisoformat(started_at_str)
                    if datetime.now() - started_at > MAX_TASK_DURATION:
                        logger.warning(f"⚠️ Задача {task_id} превысила максимальное время выполнения, помечаем как error")
                        data["status"] = "error"
                        data["error"] = f"Задача превысила максимальное время выполнения ({MAX_TASK_DURATION.total_seconds() / 60:.0f} минут)"
                        data["completed_at"] = datetime.now().isoformat()
                        continue
                except (ValueError, TypeError) as e:
                    logger.warning(f"⚠️ Не удалось проверить время выполнения задачи {task_id}: {e}")
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
