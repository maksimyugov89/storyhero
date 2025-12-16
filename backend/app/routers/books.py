import logging
import os
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Literal, Optional
from uuid import UUID

from ..db import get_db
from ..models import Book, Child, Image, ThemeStyle
from ..schemas.book import BookCreate, BookUpdate, BookOut, SceneOut
from ..services.tasks import create_task, get_task_status, find_running_task
from ..services.local_file_service import BASE_UPLOAD_DIR
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/books", tags=["books"])


class GenerateFullBookRequest(BaseModel):
    """Запрос на генерацию книги - принимает только child_id и style"""
    child_id: str
    style: Literal["storybook", "cartoon", "pixar", "disney", "watercolor"] = "storybook"


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
    child_id: Optional[int] = None
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
    
    try:
        logger.info(f"🚀 Начало генерации книги для child_id={child_id}, user_id={user_id}")
        
        # Шаг 1: Создать профиль (если child_id не передан)
        if child_id is None:
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
        logger.info(f"📖 Шаг 2: Создание сюжета для child_id={child_id}")
        plot_request = CreatePlotRequest(child_id=child_id)
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
        logger.info(f"✍️ Шаг 3: Создание текста для book_id={book_id_str}")
        text_request = CreateTextRequest(book_id=book_id_str)
        await _create_text_internal(text_request, db, user_id)
        logger.info("✓ Текст создан")
        
        # Шаг 4: Создать промпты для изображений
        logger.info(f"🎨 Шаг 4: Создание промптов для изображений")
        prompts_request = CreateImagePromptsRequest(book_id=book_id_str)
        await _create_image_prompts_internal(prompts_request, db, user_id)
        logger.info("✓ Промпты созданы")
        
        # Шаг 5: Автоматически выбрать стиль
        logger.info(f"🎭 Шаг 5: Выбор стиля")
        from ..routers.style import SelectStyleRequest, _select_style_internal
        style_request = SelectStyleRequest(book_id=book_id_str, mode="auto")
        style_result = await _select_style_internal(style_request, db, user_id)
        final_style = style_result.final_style
        logger.info(f"✓ Стиль выбран: {final_style}")
        
        # Шаг 6: Генерировать черновые изображения
        logger.info(f"🖼️ Шаг 6: Генерация черновых изображений")
        from ..routers.images import ImageRequest, _generate_draft_images_internal
        draft_request = ImageRequest(book_id=book_id_str, face_url=face_url)
        await _generate_draft_images_internal(draft_request, db, user_id, final_style=final_style)
        logger.info("✓ Черновые изображения созданы")
        
        # Шаг 7: Генерировать финальные изображения
        logger.info(f"✨ Шаг 7: Генерация финальных изображений")
        from ..routers.final_images import _generate_final_images_internal
        await _generate_final_images_internal(
            book_id=book_id_str,
            db=db,
            current_user_id=user_id,
            final_style=final_style,
            face_url=face_url
        )
        logger.info("✓ Финальные изображения созданы")
        
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
        
        # 8. Валидация стиля
        valid_styles = ["storybook", "cartoon", "pixar", "disney", "watercolor"]
        if data.style and data.style not in valid_styles:
            logger.error(f"❌ generate_full_book: Неверный стиль: {data.style}")
            raise HTTPException(
                status_code=400,
                detail=f"Неверный стиль: '{data.style}'. Доступные стили: {', '.join(valid_styles)}"
            )
        
        # 9. Метаданные для проверки дубликатов
        meta = {"user_id": user_id, "child_id": str(child.id)}

        # 10. Создаем новую задачу
        logger.info(f"✅ generate_full_book: Создание задачи для child_id={child_id_int}, style={data.style}")
        task_id = create_task(
            generate_full_book_task,
            name,
            age,
            interests,
            fears,
            personality,
            moral,
            face_url,
            data.style,
            user_id,
            db,
            child_id=child_id_int,
            meta=meta
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
            "meta": object
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

