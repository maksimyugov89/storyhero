import os
import time
import logging
from pathlib import Path

from .local_file_service import BASE_UPLOAD_DIR

logger = logging.getLogger(__name__)


def cleanup_old_drafts(retention_days: int = 7) -> None:
    """
    Удаляет черновые изображения старше retention_days в папке uploads/drafts.

    Args:
        retention_days: количество дней хранения черновых файлов
    """
    drafts_dir = Path(BASE_UPLOAD_DIR) / "drafts"
    if not drafts_dir.exists():
        logger.info(f"Папка черновиков отсутствует, пропускаем очистку: {drafts_dir}")
        return

    now = time.time()
    max_age = retention_days * 24 * 60 * 60
    deleted_files = 0
    freed_bytes = 0

    try:
        for file_path in drafts_dir.glob("**/*"):
            if file_path.is_file():
                try:
                    mtime = file_path.stat().st_mtime
                    if now - mtime > max_age:
                        size = file_path.stat().st_size
                        file_path.unlink(missing_ok=True)
                        deleted_files += 1
                        freed_bytes += size
                except Exception as e:
                    logger.warning(f"Не удалось обработать файл {file_path}: {e}")

        logger.info(
            f"Очистка черновиков завершена: удалено {deleted_files} файлов, освобождено {freed_bytes / (1024*1024):.2f} MB"
        )
    except Exception as e:
        logger.error(f"Ошибка при очистке черновых изображений: {e}", exc_info=True)

