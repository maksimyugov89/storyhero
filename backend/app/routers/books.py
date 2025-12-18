import logging
import os
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from uuid import UUID
from datetime import datetime, timezone

from ..db import get_db
from ..models import Book, Child, Image, ThemeStyle
from ..schemas.book import BookCreate, BookUpdate, BookOut, SceneOut
from ..services.tasks import create_task, get_task_status, find_running_task
from ..services.local_file_service import BASE_UPLOAD_DIR
from ..core.deps import get_current_user
from ..config.styles import (
    normalize_style,
    is_style_known,
    is_premium_style,
    check_style_access,
    deactivate_if_expired,
    ALL_STYLES,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/books", tags=["books"])


class GenerateFullBookRequest(BaseModel):
    """Запрос на генерацию книги - принимает child_id, style и num_pages"""
    child_id: str
    style: str = "classic"
    num_pages: int = 20  # 10 или 20 страниц (без обложки)


async def generate_full_book_task(
    name: str,
    age: int,
    interests: list[str],
    fears: list[str],
    personality: str,
    moral: str,
    face_url: str,
    style: str,
    user_id: str,
    db: Session,
    child_id: Optional[int] = None,
    task_id: Optional[str] = None,
    num_pages: int = 20,
    child_photos: Optional[list[str]] = None
):
    """Полный цикл генерации книги
    
    Args:
        child_id: Если передан, используется существующий профиль. Иначе создается новый.
    """
    # logger уже определен в начале файла
    
    from ..routers.profile import CreateProfileRequest, _create_profile_internal
    from ..routers.plot import CreatePlotRequest, _create_plot_internal
    from ..routers.text import CreateTextRequest, _create_text_internal
    from ..routers.image_prompts import CreateImagePromptsRequest, _create_image_prompts_internal
    from ..routers.images import ImageRequest, _generate_draft_images_internal
    from ..routers.final_images import _generate_final_images_internal
    
    from ..services.tasks import update_task_progress
    
    try:
        # ВАЖНО: проверка подписки внутри задачи (чтобы нельзя было обойти через прямой запуск фоновой задачи)
        normalized_style = normalize_style(style)
        if not is_style_known(normalized_style):
            raise HTTPException(status_code=400, detail=f"Неизвестный стиль: {style}. Доступные: {', '.join(ALL_STYLES)}")

        # Чистим истёкшие подписки пользователя перед проверкой
        deactivate_if_expired(db, user_id)

        if is_premium_style(normalized_style) and not check_style_access(db, user_id, normalized_style):
            raise HTTPException(
                status_code=403,
                detail="Этот стиль доступен только по подписке. Оформите подписку за 199 ₽/мес"
            )

        logger.info(f"🚀 Начало генерации книги для child_id={child_id}, user_id={user_id}")
        
        # Шаг 1: Создать профиль (если child_id не передан)
        if child_id is None:
            if task_id:
                update_task_progress(task_id, {
                    "stage": "creating_profile",
                    "current_step": 1,
                    "total_steps": 7,
                    "message": "Создание профиля ребёнка..."
                })
            logger.info("📝 Шаг 1: Создание нового профиля")
            profile_request = CreateProfileRequest(
                name=name,
                age=age,
                interests=interests,
                fears=fears,
                personality=personality,
                moral=moral
            )
            profile_result = await _create_profile_internal(profile_request, db, user_id)
            child_id = profile_result.child_id
            logger.info(f"✓ Профиль создан: child_id={child_id}")
        else:
            logger.info(f"✓ Используем существующий профиль: child_id={child_id}")
        
        # Шаг 2: Создать сюжет
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_plot",
                "current_step": 2,
                "total_steps": 7,
                "message": "Создание сюжета истории..."
            })
        logger.info(f"📖 Шаг 2: Создание сюжета для child_id={child_id} (num_pages={num_pages})")
        plot_request = CreatePlotRequest(child_id=child_id, num_pages=num_pages)
        plot_result = await _create_plot_internal(plot_request, db, user_id)
        book_id_str = plot_result.book_id  # UUID как строка
        logger.info(f"✓ Сюжет создан: book_id={book_id_str}")
        
        # Преобразуем строку в UUID для запросов к БД
        from uuid import UUID as UUIDType
        try:
            book_uuid = UUIDType(book_id_str)
        except ValueError:
            raise Exception(f"Неверный формат book_id: {book_id_str}")
        
        # Привязываем книгу к пользователю
        from ..models import Book
        book = db.query(Book).filter(Book.id == book_uuid).first()
        if book:
            book.user_id = user_id
            db.commit()
        
        # Шаг 3: Создать текст
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_text",
                "current_step": 3,
                "total_steps": 7,
                "message": "Генерация текста истории..."
            })
        logger.info(f"✍️ Шаг 3: Создание текста для book_id={book_id_str}")
        text_request = CreateTextRequest(book_id=book_id_str)
        await _create_text_internal(text_request, db, user_id)
        logger.info("✓ Текст создан")
        
        # ВАЖНО: После создания текста пользователь может его редактировать
        if task_id:
            update_task_progress(task_id, {
                "stage": "text_ready",
                "current_step": 3,
                "total_steps": 7,
                "message": "Текст готов! Вы можете редактировать его пока генерируются изображения.",
                "book_id": book_id_str
            })
        
        # Шаг 4: Создать промпты для изображений
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_prompts",
                "current_step": 4,
                "total_steps": 7,
                "message": "Создание промптов для изображений..."
            })
        logger.info(f"🎨 Шаг 4: Создание промптов для изображений")
        prompts_request = CreateImagePromptsRequest(book_id=book_id_str)
        await _create_image_prompts_internal(prompts_request, db, user_id)
        logger.info("✓ Промпты созданы")
        
        # Шаг 5: Выбрать стиль (manual по запросу фронтенда)
        if task_id:
            update_task_progress(task_id, {
                "stage": "selecting_style",
                "current_step": 5,
                "total_steps": 7,
                "message": "Выбор стиля иллюстраций..."
            })
        logger.info(f"🎭 Шаг 5: Выбор стиля")
        from ..routers.style import SelectStyleRequest, _select_style_internal
        style_request = SelectStyleRequest(book_id=book_id_str, mode="manual", style=normalized_style)
        style_result = await _select_style_internal(style_request, db, user_id)
        final_style = style_result.final_style
        logger.info(f"✓ Стиль выбран: {final_style}")
        
        # Шаг 6: Генерировать черновые изображения
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_images",
                "current_step": 6,
                "total_steps": 7,
                "message": "Генерация изображений...",
                "images_generated": 0,
                "total_images": 0
            })
        logger.info(f"🖼️ Шаг 6: Генерация черновых изображений")
        from ..routers.images import ImageRequest, _generate_draft_images_internal
        draft_request = ImageRequest(book_id=book_id_str, face_url=face_url)
        # Передаем task_id для обновления прогресса
        await _generate_draft_images_internal(draft_request, db, user_id, final_style=final_style, task_id=task_id)
        logger.info("✓ Черновые изображения созданы")
        
        # Шаг 7: Генерировать финальные изображения
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_final_images",
                "current_step": 7,
                "total_steps": 7,
                "message": "Генерация финальных изображений с face swap...",
                "images_generated": 0,
                "total_images": 0
            })
        logger.info(f"✨ Шаг 7: Генерация финальных изображений")
        from ..routers.final_images import _generate_final_images_internal
        try:
            await _generate_final_images_internal(
                book_id=book_id_str,
                db=db,
                current_user_id=user_id,
                final_style=final_style,
                face_url=face_url,
                task_id=task_id,
                child_photos=child_photos
            )
            logger.info("✓ Финальные изображения созданы")
        except HTTPException as e:
            # Если книга была удалена (410), это не критическая ошибка
            if e.status_code == 410:
                logger.warning(f"⚠️ Книга была удалена во время генерации финальных изображений. Генерация прервана.")
                raise Exception(f"Книга была удалена во время генерации: {e.detail}")
            # Для других HTTP ошибок пробрасываем как есть
            raise Exception(f"Ошибка при генерации финальных изображений: {e.detail}")
        
        # Генерация завершена
        if task_id:
            update_task_progress(task_id, {
                "stage": "images_ready",
                "current_step": 7,
                "total_steps": 7,
                "message": "Рендеринг изображений завершён! Теперь вы можете редактировать их.",
                "book_id": book_id_str
            })
        
        logger.info(f"✅ Генерация книги завершена: book_id={book_id_str}, child_id={child_id}")
        return {
            "child_id": child_id,
            "book_id": book_id_str,
            "status": "success"  # Изменено: completed -> success для соответствия контракту
        }
    except HTTPException as e:
        # HTTPException имеет атрибут detail, извлекаем его
        error_message = f"Ошибка при генерации книги: {e.detail}"
        logger.error(f"❌ generate_full_book_task: {error_message}", exc_info=True)
        logger.error(f"❌ generate_full_book_task: Детали ошибки - child_id={child_id}, user_id={user_id}, style={style}")
        raise Exception(error_message)
    except Exception as e:
        error_message = f"Ошибка при генерации книги: {str(e)}"
        logger.error(f"❌ generate_full_book_task: {error_message}", exc_info=True)
        # Детальное логирование для диагностики
        logger.error(f"❌ generate_full_book_task: Детали ошибки - child_id={child_id}, user_id={user_id}, style={style}")
        raise Exception(error_message)


@router.post("/generate_full_book")
async def generate_full_book_endpoint(
    data: GenerateFullBookRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Запустить полный цикл генерации книги для существующего ребёнка.
    
    Получает данные ребёнка из локальной БД по child_id.
    
    ВАЛИДАЦИЯ:
    - Проверяет наличие child_id
    - Проверяет существование ребёнка
    - Проверяет права доступа (ребёнок принадлежит пользователю)
    - Проверяет наличие обязательных полей (name, age)
    - Проверяет дубликаты задач (если уже есть running задача для этого child_id)
    
    Returns:
        {
            "task_id": "uuid",
            "message": "Книга генерируется",
            "child_id": "integer"
        }
    
    Raises:
        400: Неверный формат child_id или отсутствуют обязательные поля
        401: Не авторизован
        403: Ребёнок принадлежит другому пользователю
        404: Ребёнок не найден
        409: Уже есть активная задача генерации для этого ребёнка
        500: Внутренняя ошибка сервера
    """
    from ..models import Child
    
    import logging
    logger = logging.getLogger(__name__)
    
    try:
        # 1. Проверка авторизации
        user_id = current_user.get("sub") or current_user.get("id")
        if not user_id:
            logger.error("❌ generate_full_book: Отсутствует user_id в токене")
            raise HTTPException(
                status_code=401,
                detail="Требуется авторизация. Пожалуйста, войдите в систему."
            )
        
        # 2. Валидация child_id
        if not data.child_id:
            logger.error("❌ generate_full_book: child_id не передан")
            raise HTTPException(
                status_code=400,
                detail="Не указан ID ребёнка (child_id). Пожалуйста, выберите ребёнка для создания книги."
            )
        
        try:
            child_id_int = int(data.child_id)
        except (ValueError, TypeError):
            logger.error(f"❌ generate_full_book: Неверный формат child_id: {data.child_id}")
            raise HTTPException(
                status_code=400,
                detail=f"Неверный формат ID ребёнка: '{data.child_id}'. Ожидается число."
            )
        
        # 3. Проверка существования ребёнка
        child = db.query(Child).filter(Child.id == child_id_int).first()
        if not child:
            logger.error(f"❌ generate_full_book: Ребёнок с ID {child_id_int} не найден")
            raise HTTPException(
                status_code=404,
                detail=f"Ребёнок с ID {child_id_int} не найден. Пожалуйста, создайте профиль ребёнка."
            )
        
        # 4. Проверка прав доступа
        if child.user_id != user_id:
            logger.error(f"❌ generate_full_book: Ребёнок {child_id_int} принадлежит другому пользователю")
            raise HTTPException(
                status_code=403,
                detail="Доступ запрещён. Этот ребёнок принадлежит другому пользователю."
            )
        
        # 5. Проверка обязательных полей
        if not child.name or not child.name.strip():
            logger.error(f"❌ generate_full_book: У ребёнка {child_id_int} отсутствует имя")
            raise HTTPException(
                status_code=400,
                detail="У ребёнка не указано имя. Пожалуйста, заполните профиль ребёнка."
            )
        
        if not child.age or child.age <= 0:
            logger.error(f"❌ generate_full_book: У ребёнка {child_id_int} не указан возраст")
            raise HTTPException(
                status_code=400,
                detail="У ребёнка не указан возраст. Пожалуйста, заполните профиль ребёнка."
            )
        
        # 6. Проверка дубликатов задач (через find_running_task)
        from ..services.tasks import find_running_task
        existing_task = find_running_task({"user_id": user_id, "child_id": str(child_id_int)})
        if existing_task:
            logger.warning(f"⚠️ generate_full_book: Уже есть активная задача {existing_task['task_id']} для child_id={child_id_int}")
            return {
                "task_id": existing_task["task_id"],
                "message": "Книга уже генерируется",
                "child_id": str(child_id_int)
            }
        
        # 7. Извлекаем данные из БД
        name = child.name
        age = child.age
        interests = child.interests if isinstance(child.interests, list) else []
        fears = child.fears if isinstance(child.fears, list) else []
        personality = child.personality or ""
        moral = child.moral or ""
        face_url = child.face_url or ""
        
        # 7.1. Получаем все фотографии ребёнка (до 5 штук) для лучшего face swap
        import os
        from ..services.local_file_service import BASE_UPLOAD_DIR
        child_photos = []
        photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id_int))
        if os.path.exists(photos_dir):
            photo_files = [
                f for f in os.listdir(photos_dir)
                if f.lower().endswith(('.jpg', '.jpeg', '.png', '.webp'))
            ]
            # Сортируем и берем до 5 фото
            photo_files = sorted(photo_files)[:5]
            from ..services.local_file_service import get_server_base_url
            base_url = get_server_base_url()
            child_photos = [
                os.path.join(photos_dir, filename) for filename in photo_files
            ]
            logger.info(f"📸 Найдено фотографий ребёнка: {len(child_photos)}")
        else:
            # Если нет директории, используем face_url если есть
            if face_url:
                # Преобразуем URL в локальный путь
                if "/static/children/" in face_url:
                    filename = face_url.split("/static/children/")[1].split("/")[-1]
                    photo_path = os.path.join(photos_dir, filename)
                    if os.path.exists(photo_path):
                        child_photos = [photo_path]
                        logger.info(f"📸 Используем face_url как фото: {photo_path}")
        
        # 8. Валидация num_pages (только 10 или 20 — как на фронтенде)
        num_pages = data.num_pages if hasattr(data, 'num_pages') and data.num_pages else 20
        if num_pages not in (10, 20):
            raise HTTPException(status_code=400, detail="Количество страниц должно быть 10 или 20")
        
        # 9. Валидация стиля (25 стилей) + алиасы (storybook -> classic)
        normalized_style = normalize_style(data.style)
        if not is_style_known(normalized_style):
            raise HTTPException(status_code=400, detail=f"Неизвестный стиль: {data.style}. Доступные: {', '.join(ALL_STYLES)}")

        # 9.1 Проверка подписки ПЕРЕД стартом генерации (и чистка истёкших подписок)
        deactivate_if_expired(db, user_id)
        if is_premium_style(normalized_style) and not check_style_access(db, user_id, normalized_style):
            raise HTTPException(
                status_code=403,
                detail="Этот стиль доступен только по подписке. Оформите подписку за 199 ₽/мес"
            )
        
        # 9. Метаданные для проверки дубликатов
        meta = {"user_id": user_id, "child_id": str(child.id)}

        # 10. Создаем новую задачу
        logger.info(f"✅ generate_full_book: Создание задачи для child_id={child_id_int}, style={normalized_style}")
        # Сначала создаем task_id, чтобы передать его в функцию
        import uuid as uuid_module
        task_id = str(uuid_module.uuid4())
        task_id = create_task(
            generate_full_book_task,
            name,
            age,
            interests,
            fears,
            personality,
            moral,
            face_url,
            normalized_style,
            user_id,
            db,
            child_id=child_id_int,
            num_pages=num_pages,
            child_photos=child_photos,
            meta=meta,
            task_id=task_id
        )
        
        logger.info(f"✅ generate_full_book: Задача создана: task_id={task_id}")
        return {
            "task_id": task_id,
            "message": "Книга генерируется",
            "child_id": str(child_id_int)
        }
        
    except HTTPException:
        # Пробрасываем HTTP исключения как есть (они уже имеют правильные статусы и сообщения)
        raise
    except Exception as e:
        logger.error(f"❌ generate_full_book: Неожиданная ошибка: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Внутренняя ошибка сервера при создании задачи генерации книги. Пожалуйста, попробуйте позже."
        )


@router.get("/task_status/{task_id}")
def get_task_status_endpoint(
    task_id: str,
    current_user: dict = Depends(get_current_user)
):
    """
    Получить статус задачи генерации книги.
    
    Требуется авторизация. Возвращает статус задачи (pending | running | success | error).
    
    ВАЖНО: Статусы соответствуют контракту:
    - pending: Задача создана, ожидает запуска
    - running: Задача выполняется
    - success: Задача успешно завершена
    - error: Задача завершилась с ошибкой
    
    Returns:
        {
            "status": "pending | running | success | error",
            "created_at": "ISO datetime string",
            "result": object | null,
            "error": "string | null",
            "completed_at": "ISO datetime string | null",
            "meta": object,
            "progress": {
                "stage": "creating_profile | creating_plot | creating_text | text_ready | creating_prompts | selecting_style | generating_images | generating_final_images | images_ready",
                "current_step": int,
                "total_steps": int,
                "message": string,
                "images_generated": int,
                "total_images": int,
                "percent": int (0-100),
                "book_id": string | null
            }
        }
    
    Raises:
        HTTPException 404: Если задача не найдена
    """
    task_status = get_task_status(task_id)
    
    if not task_status:
        raise HTTPException(
            status_code=404,
            detail="Задача не найдена"
        )
    
    # Гарантируем, что статус соответствует контракту
    valid_statuses = ["pending", "running", "success", "error"]
    current_status = task_status.get("status", "pending")
    
    # Нормализуем статус: completed -> success (для обратной совместимости)
    if current_status == "completed":
        task_status["status"] = "success"
        current_status = "success"
    
    if current_status not in valid_statuses:
        logger.warning(f"⚠️ get_task_status: Неожиданный статус задачи {task_id}: {current_status}, нормализуем в 'error'")
        task_status["status"] = "error"
    
    # Вычисляем процент выполнения для фронтенда
    progress = task_status.get("progress", {})
    if progress:
        current_step = progress.get("current_step", 0)
        total_steps = progress.get("total_steps", 7)
        images_generated = progress.get("images_generated", 0)
        total_images = progress.get("total_images", 0)
        stage = progress.get("stage", "starting")
        pages_rendered = progress.get("pages_rendered", 0)
        total_pages = progress.get("total_pages", 0)
        
        # Вычисляем общий процент
        # Шаги 1-5 занимают 30% (по 6% на шаг)
        # Шаги 6-7 (генерация изображений) занимают 70% (по 35% на шаг)
        if stage in ["generating_images", "generating_final_images"]:
            # При генерации изображений учитываем прогресс по изображениям
            base_percent = 30  # Шаги 1-5 завершены
            if stage == "generating_final_images":
                base_percent = 65  # Шаги 1-6 завершены
            
            if total_images > 0:
                image_progress = (images_generated / total_images) * 35
            else:
                image_progress = 0
            
            percent = int(base_percent + image_progress)
        elif stage in ["rendering_pdf", "pdf_ready"]:
            # PDF — финальный этап, отображаем как 90-100%
            if total_pages and total_pages > 0:
                pdf_progress = (pages_rendered / total_pages) * 10
            else:
                pdf_progress = 0
            base_percent = 90
            percent = int(base_percent + pdf_progress)
        elif stage == "images_ready":
            percent = 100
        elif current_status == "success":
            percent = 100
        elif current_status == "error":
            # Оставляем процент на момент ошибки
            percent = int((current_step / total_steps) * 100) if total_steps > 0 else 0
        else:
            # Для этапов 1-5
            percent = int((current_step / total_steps) * 30) if total_steps > 0 else 0
        
        # Гарантируем, что процент в диапазоне 0-100
        percent = max(0, min(100, percent))
        progress["percent"] = percent
        
        # Обновляем progress в ответе
        task_status["progress"] = progress
    else:
        # Если progress пустой, добавляем базовый
        task_status["progress"] = {
            "stage": "starting",
            "current_step": 0,
            "total_steps": 7,
            "message": "Инициализация...",
            "images_generated": 0,
            "total_images": 0,
            "percent": 0
        }
    
    return task_status


# ============================================
# CRUD ОПЕРАЦИИ ДЛЯ КНИГ
# ============================================


@router.get("/", response_model=list[BookOut])
@router.get("", response_model=list[BookOut])  # Чтобы не было редиректа /books -> /books/
def get_books(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить все книги текущего пользователя.
    
    Возвращает список всех книг из базы данных, принадлежащих текущему пользователю.
    """
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    # Book.user_id хранится как String, поэтому сравниваем строки
    # Фильтруем книги по user_id текущего пользователя
    try:
        books = db.query(Book).filter(Book.user_id == str(user_id)).order_by(Book.created_at.desc()).all()
        logger.info(f"✅ get_books: Найдено {len(books)} книг для user_id={user_id}")
        return books
    except Exception as e:
        logger.error(f"❌ get_books: Ошибка при получении книг для user_id={user_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Внутренняя ошибка сервера при получении книг: {str(e)}"
        )


@router.get("/{book_id}", response_model=BookOut)
def get_book(
    book_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить книгу по ID.
    
    Args:
        book_id: UUID книги
        
    Returns:
        BookOut: Данные книги
        
    Raises:
        HTTPException 404: Если книга не найдена или не принадлежит пользователю
    """
    user_id = str(current_user.get("sub") or current_user.get("id"))
    book = db.query(Book).filter(
        Book.id == book_id,
        Book.user_id == user_id
    ).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found or access denied")
    return book


@router.get("/{book_id}/scenes", response_model=list[SceneOut])
def get_book_scenes(
    book_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить все сцены книги по ID.
    
    ВАЖНО: Все строковые поля ВСЕГДА возвращаются как строки (пустая строка "" если null),
    чтобы гарантировать null-safety для фронтенда.
    
    Args:
        book_id: UUID книги
        
    Returns:
        List[SceneOut]: Массив сцен книги (не объект!)
        
    Raises:
        HTTPException 404: Если книга не найдена или не принадлежит пользователю
    """
    from ..models import Scene
    
    user_id = str(current_user.get("sub") or current_user.get("id"))
    
    # Проверяем, что книга существует и принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_id,
        Book.user_id == user_id
    ).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found or access denied")
    
    # Получаем сцены книги
    scenes = db.query(Scene).filter(
        Scene.book_id == book_id
    ).order_by(Scene.order).all()
    
    # Получаем все изображения для этих сцен (для получения image_url)
    from ..models import Image
    images = db.query(Image).filter(
        Image.book_id == book_id
    ).all()
    # Создаем словарь для быстрого поиска: scene_order -> final_url
    images_by_order = {img.scene_order: img.final_url for img in images if img.final_url}
    
    # Формируем ответ используя Pydantic модель для валидации и null-safety
    scenes_response = []
    for scene in scenes:
        # Гарантируем, что все текстовые поля - строки (не null)
        # Используем явную проверку на None и приведение к строке
        short_summary = str(scene.short_summary) if scene.short_summary is not None else ""
        text = str(scene.text) if scene.text is not None else ""
        illustration_prompt = str(scene.image_prompt) if scene.image_prompt is not None else ""
        
        # Получаем image_url из связанного изображения
        image_url = str(images_by_order.get(scene.order, "")) if images_by_order.get(scene.order) else ""
        
        # audio_url пока не используется (может быть добавлен позже)
        audio_url = ""
        
        # title пока не используется (может быть добавлен позже)
        title = ""
        
        # created_at может быть null, но возвращаем как строку или null явно
        created_at_str = None
        if scene.created_at is not None:
            try:
                created_at_str = scene.created_at.isoformat()
            except (AttributeError, ValueError):
                created_at_str = None
        
        # Создаем объект через Pydantic модель для валидации
        scene_out = SceneOut(
            id=int(scene.id),
            order=int(scene.order),
            title=title,
            text=text,
            short_summary=short_summary,
            image_url=image_url,
            audio_url=audio_url,
            illustration_prompt=illustration_prompt,
            created_at=created_at_str
        )
        
        scenes_response.append(scene_out)
    
    # ВАЖНО: Возвращаем массив, а не объект {"scenes": [...]}
    # Pydantic автоматически сериализует список SceneOut в JSON
    return scenes_response


@router.post("/", response_model=BookOut)
def create_book(
    data: BookCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создать новую книгу.
    
    Args:
        data: Данные для создания книги (BookCreate)
        
    Returns:
        BookOut: Созданная книга
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    book_data = data.model_dump()
    book_data["user_id"] = user_id  # Привязываем к текущему пользователю
    book = Book(**book_data)
    db.add(book)
    db.commit()
    db.refresh(book)
    return book


@router.put("/{book_id}", response_model=BookOut)
def update_book(
    book_id: UUID,
    data: BookUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Обновить книгу по ID.
    
    Args:
        book_id: UUID книги
        data: Данные для обновления (BookUpdate)
        
    Returns:
        BookOut: Обновлённая книга
        
    Raises:
        HTTPException 404: Если книга не найдена или не принадлежит пользователю
    """
    user_id = str(current_user.get("sub") or current_user.get("id"))
    book = db.query(Book).filter(
        Book.id == book_id,
        Book.user_id == user_id
    ).first()
    if not book:
        raise HTTPException(status_code=404, detail="Book not found or access denied")

    # Обновляем только переданные поля
    update_data = data.model_dump(exclude_unset=True)
    for key, value in update_data.items():
        setattr(book, key, value)

    db.commit()
    db.refresh(book)
    return book


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book(
    book_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Удалить книгу по ID (идемпотентная операция).
    
    Требуется авторизация. Пользователь может удалять только свои книги.
    При удалении книги также удаляются все связанные данные:
    - Сцены (scenes)
    - Изображения (images)
    - Стили (theme_styles)
    - Файлы на диске (PDF, изображения)
    
    ИДЕМПОТЕНТНОСТЬ:
    - Если книга уже удалена → возвращает 204 (успешно)
    - Если книга не найдена → возвращает 410 Gone (уже удалена)
    - Если книга принадлежит другому пользователю → возвращает 403
    
    Args:
        book_id: UUID книги
        
    Returns:
        204 No Content - при успешном удалении или если уже удалена
        
    Raises:
        HTTPException 401: Если не авторизован
        HTTPException 403: Если нет прав на удаление (книга принадлежит другому пользователю)
        HTTPException 410: Если книга не найдена (уже удалена)
        HTTPException 500: При внутренней ошибке сервера
    """
    
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Требуется авторизация")
    
    try:
        # Найти книгу по ID
        book = db.query(Book).filter(Book.id == book_id).first()
        
        # ИДЕМПОТЕНТНОСТЬ: Если книга не найдена, считаем что уже удалена
        if not book:
            # Возвращаем 204 (успешно) для идемпотентности
            # Альтернатива: можно вернуть 410 Gone, но 204 более безопасен для UI
            return None
        
        # Проверить права доступа
        if book.user_id != user_id:
            raise HTTPException(
                status_code=403,
                detail="Нет прав на удаление этой книги"
            )
        
        # Логируем операцию удаления
        logger.info(f"Удаление книги {book_id} пользователем {user_id}")
        
        # Собираем все URL файлов для удаления
        files_to_delete = []
        
        # PDF файл книги
        if book.final_pdf_url:
            files_to_delete.append(book.final_pdf_url)
        
        # Обложка книги
        if book.cover_url:
            files_to_delete.append(book.cover_url)
        
        # Получаем все изображения книги перед удалением
        images = db.query(Image).filter(Image.book_id == book_id).all()
        for image in images:
            if image.draft_url:
                files_to_delete.append(image.draft_url)
            if image.final_url:
                files_to_delete.append(image.final_url)
        
        # Удаляем файлы на диске
        for file_url in files_to_delete:
            try:
                # Извлекаем относительный путь из URL
                # Формат URL: http://host:port/static/path/to/file
                if "/static/" in file_url:
                    relative_path = file_url.split("/static/", 1)[1]
                    file_path = os.path.join(BASE_UPLOAD_DIR, relative_path)
                    
                    if os.path.exists(file_path):
                        os.remove(file_path)
                        logger.info(f"Удален файл: {file_path}")
                    else:
                        logger.warning(f"Файл не найден на диске: {file_path}")
            except Exception as e:
                # Не критично, если файл не удалось удалить
                logger.warning(f"Не удалось удалить файл {file_url}: {str(e)}")
        
        # Удаление связанных данных происходит автоматически через CASCADE
        # Scene, Image, ThemeStyle удалятся автоматически благодаря ondelete="CASCADE"
        
        # Сохраняем информацию о книге для логирования
        book_title = book.title
        book_child_id = book.child_id
        
        # Удаляем книгу из БД
        db.delete(book)
        # Явно делаем flush перед commit для гарантии атомарности
        db.flush()
        db.commit()
        
        logger.info(f"✅ Книга {book_id} (title: '{book_title}', child_id: {book_child_id}) успешно удалена из БД")
        logger.info(f"   После удаления книга больше не будет возвращаться в списках GET /books и GET /children/{{child_id}}/books")
        
        # 204 No Content - пустое тело ответа
        # Клиент должен обновить список книг после получения этого статуса
        return None
        
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Ошибка при удалении книги {book_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="Внутренняя ошибка сервера"
        )

