"""
Роутер для генерации полной книги через асинхронные задачи.
"""
import logging
from typing import Optional, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel

from ..db import get_db
from ..models import Child, Book
from ..core.deps import get_current_user
from ..services.tasks import create_task, update_task_progress, get_task_status
from ..routers.plot import _create_plot_internal, CreatePlotRequest
from ..routers.text import _create_text_internal, CreateTextRequest
from ..routers.image_prompts import _create_image_prompts_internal, CreateImagePromptsRequest
from ..routers.images import _generate_draft_images_internal, ImageRequest
from ..routers.final_images import _generate_final_images_internal
from ..routers.style import _select_style_internal, SelectStyleRequest
from ..models import Scene, Image as ImageModel
from ..services.pdf_service import PdfPage, render_book_pdf
from ..services.storage import BASE_UPLOAD_DIR, get_server_base_url
from pathlib import Path
import asyncio
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


@router.get("")
def list_books(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить список всех книг текущего пользователя."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    # user_id в БД хранится как строка, сравниваем как строки
    books = db.query(Book).filter(Book.user_id == str(user_id)).all()
    
    result = []
    for book in books:
        # Преобразуем is_paid из строки "true"/"false" в boolean
        is_paid = False
        if book.is_paid:
            is_paid = book.is_paid.lower() == "true"
        
        result.append({
            "id": str(book.id),
            "title": book.title,
            "status": book.status,
            "child_id": book.child_id,
            "created_at": book.created_at.isoformat() if book.created_at else None,
            "is_paid": is_paid  # Добавлено поле is_paid как boolean
        })
    
    return result


@router.get("/{book_id}")
def get_book(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить книгу по ID."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    # Преобразуем book_id в UUID
    from uuid import UUID
    try:
        book_uuid = UUID(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # user_id в БД хранится как строка, сравниваем как строки
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == str(user_id)
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail=f"Книга с id={book_id} не найдена")
    
    # Преобразуем is_paid из строки "true"/"false" в boolean
    is_paid = False
    if book.is_paid:
        is_paid = book.is_paid.lower() == "true"
    
    return {
        "id": str(book.id),
        "title": book.title,
        "status": book.status,
        "child_id": book.child_id,
        "created_at": book.created_at.isoformat() if book.created_at else None,
        "final_pdf_url": book.final_pdf_url,
        "is_paid": is_paid  # Добавлено поле is_paid как boolean
    }


@router.get("/{book_id}/scenes")
def get_book_scenes(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить сцены книги по ID."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    # Преобразуем book_id в UUID
    from uuid import UUID
    try:
        book_uuid = UUID(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем, что книга существует и принадлежит пользователю
    # user_id в БД хранится как строка, сравниваем как строки
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == str(user_id)
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail=f"Книга с id={book_id} не найдена")
    
    # Получаем сцены книги
    scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
    
    # Получаем изображения для сцен
    images = db.query(ImageModel).filter(ImageModel.book_id == book_uuid).all()
    images_by_scene = {img.scene_order: img for img in images}
    
    result = []
    for scene in scenes:
        image = images_by_scene.get(scene.order)
        # КРИТИЧНО: Формат должен соответствовать ожиданиям фронтенда!
        # Фронтенд ожидает: id, book_id, order, short_summary, image_prompt, draft_url, image_url
        result.append({
            "id": str(scene.id),  # ОБЯЗАТЕЛЬНО: фронтенд требует id
            "book_id": str(book.id),  # ОБЯЗАТЕЛЬНО: фронтенд требует book_id
            "order": int(scene.order),  # КРИТИЧНО: Явно преобразуем в int, чтобы гарантировать числовой тип
            "short_summary": scene.short_summary or "",  # ОБЯЗАТЕЛЬНО: не может быть None
            "text": scene.text,  # Опционально, но возвращаем
            "image_prompt": scene.image_prompt,  # Опционально
            "draft_url": image.draft_url if image and image.draft_url else None,  # draft_url, не draft_image_url!
            "image_url": image.final_url if image and image.final_url else None  # image_url, не final_image_url!
        })
    
    return result


@router.delete("/{book_id}")
def delete_book(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Удалить книгу по ID.
    
    ВАЖНО: Пользователь может удалять любые свои книги, включая оплаченные.
    Ограничений на удаление оплаченных книг нет.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    # Преобразуем book_id в UUID
    from uuid import UUID
    try:
        book_uuid = UUID(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем, что книга существует и принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == str(user_id)  # Сравниваем user_id как строку
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail=f"Книга с id={book_id} не найдена")
    
    # Удаляем связанные данные
    # КРИТИЧНО: Используем raw SQL для всех удалений, чтобы полностью обойти SQLAlchemy ORM
    from sqlalchemy import text
    
    # 1. Удаляем заказы на печать через raw SQL (КРИТИЧНО: перед удалением книги, так как book_id NOT NULL)
    db.execute(
        text("DELETE FROM print_orders WHERE book_id = :book_id"),
        {"book_id": str(book_uuid)}
    )
    
    # 2. Удаляем изображения через raw SQL
    db.execute(
        text("DELETE FROM images WHERE book_id = :book_id"),
        {"book_id": str(book_uuid)}
    )
    
    # 3. Удаляем ThemeStyle через raw SQL (если есть)
    db.execute(
        text("DELETE FROM theme_styles WHERE book_id = :book_id"),
        {"book_id": str(book_uuid)}
    )
    
    # 4. Удаляем сцены через raw SQL (они удалятся автоматически благодаря cascade, но удаляем явно)
    db.execute(
        text("DELETE FROM scenes WHERE book_id = :book_id"),
        {"book_id": str(book_uuid)}
    )
    
    # 5. Удаляем книгу через raw SQL
    db.execute(
        text("DELETE FROM books WHERE id = :book_id"),
        {"book_id": str(book_uuid)}
    )
    
    # КРИТИЧНО: Commit всех удалений одной транзакцией
    db.commit()
    
    # Очищаем кеш сессии после всех удалений
    db.expire_all()
    
    logger.info(f"✅ Книга {book_id} успешно удалена пользователем {user_id}")
    
    return {"message": "Книга успешно удалена", "book_id": book_id}


@router.get("/task_status/{task_id}")
def get_task_status_endpoint(
    task_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить статус задачи генерации книги."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    task_data = get_task_status(task_id)
    
    # Если задача не найдена в памяти, проверяем, не была ли она прервана при перезапуске
    if not task_data:
        # Пытаемся найти книгу по task_id в метаданных других задач или по book_id
        # Ищем книги пользователя со статусом "draft", которые могли быть прерваны
        from app.models import Scene, Image as ImageModel, ThemeStyle
        from uuid import UUID
        
        # Ищем книги пользователя, которые находятся в процессе генерации
        # (статус "draft" и есть сцены, но нет финальных изображений или PDF)
        books = db.query(Book).filter(
            Book.user_id == str(user_id),
            Book.status == "draft"
        ).all()
        
        for book in books:
            # Проверяем состояние книги, чтобы определить, на каком этапе остановилась генерация
            scenes = db.query(Scene).filter(Scene.book_id == book.id).all()
            images = db.query(ImageModel).filter(ImageModel.book_id == book.id).all()
            
            if not scenes:
                continue  # Книга не начала генерацию
            
            # Определяем этап генерации
            has_text = any(scene.text for scene in scenes)
            has_prompts = any(scene.image_prompt for scene in scenes)
            has_draft_images = any(img.draft_url for img in images)
            has_final_images = any(img.final_url for img in images)
            has_pdf = book.final_pdf_url is not None
            
            # Определяем stage на основе состояния книги
            if has_pdf:
                stage = "completed"
                current_step = 8
                message = "Книга готова!"
            elif has_final_images:
                stage = "generating_pdf"
                current_step = 8
                message = "Генерация была прервана при создании PDF. Книга готова для продолжения генерации PDF."
            elif has_draft_images:
                stage = "generating_final_images"
                current_step = 7
                message = "Генерация была прервана при перезапуске сервера. Книга готова для продолжения генерации финальных изображений."
            elif has_prompts:
                stage = "generating_draft_images"
                current_step = 6
                message = "Генерация была прервана при перезапуске сервера. Книга готова для продолжения генерации черновых изображений."
            elif has_text:
                stage = "text_ready"
                current_step = 3
                message = "Генерация была прервана при перезапуске сервера. Книга готова для продолжения генерации."
            else:
                stage = "creating_plot"
                current_step = 2
                message = "Генерация была прервана при перезапуске сервера. Книга готова для продолжения генерации."
            
            # Возвращаем информацию о прерванной задаче
            return {
                "id": task_id,
                "status": "interrupted",  # Новый статус для прерванных задач
                "created_at": book.created_at.isoformat() if book.created_at else None,
                "result": None,
                "error": None,
                "meta": {
                    "user_id": user_id,
                    "book_id": str(book.id),
                    "type": "generate_full_book"
                },
                "progress": {
                    "stage": stage,
                    "current_step": current_step,
                    "total_steps": 8,
                    "message": message,
                    "book_id": str(book.id),
                    "interrupted": True,  # Флаг, что задача была прервана
                    "updated_at": book.updated_at.isoformat() if book.updated_at else None
                }
            }
        
        # Если книга не найдена, возвращаем 404
        raise HTTPException(status_code=404, detail="Задача не найдена")
    
    # Проверяем, что задача принадлежит текущему пользователю
    task_meta = task_data.get("meta", {})
    if task_meta.get("user_id") != user_id:
        raise HTTPException(status_code=403, detail="Доступ запрещён")
    
    return {
        "id": task_id,  # Добавляем id задачи в ответ
        "status": task_data.get("status", "unknown"),
        "created_at": task_data.get("created_at"),
        "result": task_data.get("result"),
        "error": task_data.get("error"),
        "meta": task_data.get("meta", {}),
        "progress": task_data.get("progress", {})
    }


@router.post("/{book_id}/continue_generation")
async def continue_generation(
    book_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Продолжить генерацию прерванной книги.
    
    Определяет этап генерации на основе состояния книги и продолжает с нужного места.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    from uuid import UUID
    try:
        book_uuid = UUID(book_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат book_id: {book_id}")
    
    # Проверяем, что книга существует и принадлежит пользователю
    book = db.query(Book).filter(
        Book.id == book_uuid,
        Book.user_id == str(user_id)
    ).first()
    
    if not book:
        raise HTTPException(status_code=404, detail=f"Книга с id={book_id} не найдена")
    
    # Проверяем состояние книги
    from app.models import Scene, Image as ImageModel, ThemeStyle, Child
    scenes = db.query(Scene).filter(Scene.book_id == book_uuid).all()
    images = db.query(ImageModel).filter(ImageModel.book_id == book_uuid).all()
    
    if not scenes:
        raise HTTPException(status_code=400, detail="Книга не начала генерацию. Используйте /generate_full_book")
    
    # Определяем этап генерации
    has_draft_images = any(img.draft_url for img in images)
    has_final_images = any(img.final_url for img in images)
    has_pdf = book.final_pdf_url is not None
    
    # Получаем данные ребёнка
    child = db.query(Child).filter(Child.id == book.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
    
    # Получаем стиль
    theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
    if not theme_style:
        raise HTTPException(status_code=400, detail="Стиль не выбран. Сначала выберите стиль.")
    
    final_style = theme_style.final_style
    
    # Определяем, с какого этапа продолжать
    if has_pdf:
        raise HTTPException(status_code=400, detail="Книга уже полностью сгенерирована")
    elif has_final_images:
        raise HTTPException(
            status_code=400,
            detail=f"Финальные изображения готовы. Используйте /books/{book_id}/generate_final_version для создания PDF"
        )
    elif has_draft_images:
        # Продолжаем с генерации финальных изображений
        logger.info(f"🔄 Продолжение генерации: финальные изображения для книги {book_id}")
        
        # Получаем фотографии ребёнка
        from ..routers.children import get_child_photos
        try:
            child_photos_data = get_child_photos(child.id, db, current_user)
            child_photos = [photo["url"] for photo in child_photos_data.get("photos", [])] if child_photos_data else []
        except:
            child_photos = []
        
        face_url = child_photos[0] if child_photos else None
        if not face_url:
            raise HTTPException(status_code=400, detail="Не найдены фотографии ребёнка")
        
        # Создаем задачу для продолжения генерации финальных изображений
        from ..services.tasks import create_task
        from ..routers.final_images import _generate_final_images_internal
        
        task_id = create_task(
            _generate_final_images_internal,
            book_id,
            db,
            user_id,
            final_style=final_style,
            face_url=face_url,
            child_photos=child_photos,
            meta={
                "type": "continue_generation",
                "user_id": user_id,
                "book_id": book_id,
                "stage": "generating_final_images"
            }
        )
        
        return {
            "task_id": task_id,
            "message": "Продолжение генерации финальных изображений запущено",
            "book_id": book_id,
            "stage": "generating_final_images"
        }
    else:
        raise HTTPException(
            status_code=400,
            detail="Книга находится на начальном этапе. Используйте /generate_full_book для полной генерации"
        )


class GenerateFullBookRequest(BaseModel):
    """Запрос на генерацию книги - принимает child_id, style, num_pages и theme"""
    child_id: str
    style: str = "classic"
    num_pages: int = 20  # 10 или 20 страниц (без обложки)
    theme: str  # Тема книги (обязательное поле) - о чём будет книга


async def generate_full_book_task(
    name: str,
    age: int,
    interests: List[str],
    fears: List[str],
    personality: str,
    moral: str,
    face_url: str,
    style: str,
    user_id: str,
    db: Session,
    child_id: Optional[int] = None,
    task_id: Optional[str] = None,
    num_pages: int = 20,
    child_photos: Optional[List[str]] = None,
    theme: Optional[str] = None  # Тема книги
):
    """
    Асинхронная задача для генерации полной книги.
    
    Args:
        name: Имя ребёнка
        age: Возраст ребёнка
        interests: Список интересов
        fears: Список страхов
        personality: Характер
        moral: Мораль/ценности
        face_url: URL фото ребёнка
        style: Стиль иллюстраций
        user_id: ID пользователя
        db: Сессия БД
        child_id: ID ребёнка (опционально)
        task_id: ID задачи для отслеживания прогресса
        num_pages: Количество страниц (10 или 20)
        child_photos: Список URL фотографий ребёнка
        theme: Тема книги (о чём будет книга)
    """
    from ..services.subscription_service import check_and_update_user_subscription_status
    
    try:
        # Проверяем и обновляем статус подписки пользователя
        check_and_update_user_subscription_status(db, user_id)
        
        if task_id:
            update_task_progress(task_id, {
                "stage": "starting",
                "current_step": 1,
                "total_steps": 7,
                "message": "Инициализация генерации книги...",
                "theme": theme or "не указана"
            })
        
        logger.info(f"📖 Шаг 1: Начало генерации книги для child_id={child_id} (theme={theme})")
        
        # Шаг 2: Создание сюжета
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_plot",
                "current_step": 2,
                "total_steps": 7,
                "message": "Создание сюжета книги...",
            })
        
        logger.info(f"📖 Шаг 2: Создание сюжета для child_id={child_id} (num_pages={num_pages}, theme={theme})")
        plot_request = CreatePlotRequest(child_id=child_id, num_pages=num_pages, theme=theme)
        # Передаем task_id в _create_plot_internal для обновления progress сразу после создания книги
        plot_result = await _create_plot_internal(plot_request, db, user_id, task_id=task_id)
        
        # Обновляем progress после завершения создания сюжета (book_id уже добавлен в _create_plot_internal)
        if task_id:
            update_task_progress(task_id, {
                "stage": "plot_ready",
                "current_step": 2,
                "total_steps": 7,
                "message": "Сюжет создан!",
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"✓ Сюжет создан: book_id={plot_result.book_id}")
        
        # Шаг 3: Создание текста
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_text",
                "current_step": 3,
                "total_steps": 7,
                "message": "Генерация текста для сцен...",
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"✍️ Шаг 3: Создание текста для book_id={plot_result.book_id}")
        text_request = CreateTextRequest(book_id=plot_result.book_id)
        await _create_text_internal(text_request, db, user_id)
        
        if task_id:
            update_task_progress(task_id, {
                "stage": "text_ready",
                "current_step": 3,
                "total_steps": 7,
                "message": "Текст готов! Вы можете редактировать его пока генерируются изображения.",
                "book_id": str(plot_result.book_id)  # Преобразуем в строку для JSON
            })
        
        # Шаг 4: Создание промптов для изображений
        if task_id:
            update_task_progress(task_id, {
                "stage": "creating_prompts",
                "current_step": 4,
                "total_steps": 7,
                "message": "Создание промптов для изображений...",
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"🖼️ Шаг 4: Создание промптов для book_id={plot_result.book_id}")
        prompts_request = CreateImagePromptsRequest(book_id=plot_result.book_id)
        await _create_image_prompts_internal(prompts_request, db, user_id)
        
        # Шаг 5: Выбор стиля
        if task_id:
            update_task_progress(task_id, {
                "stage": "selecting_style",
                "current_step": 5,
                "total_steps": 7,
                "message": "Выбор стиля иллюстраций...",
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"🎨 Шаг 5: Выбор стиля для book_id={plot_result.book_id}")
        style_request = SelectStyleRequest(book_id=plot_result.book_id, mode="manual", style=style)
        await _select_style_internal(style_request, db, user_id)
        
        # Шаг 6: Генерация черновых изображений
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_draft_images",
                "current_step": 6,
                "total_steps": 7,
                "message": "Генерация черновых изображений...",
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"🖼️ Шаг 6: Генерация черновых изображений для book_id={plot_result.book_id}")
        image_request = ImageRequest(book_id=plot_result.book_id, face_url=face_url)
        await _generate_draft_images_internal(image_request, db, user_id, final_style=style, task_id=task_id)
        
        # Шаг 7: Генерация финальных изображений
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_final_images",
                "current_step": 7,
                "total_steps": 7,
                "message": "Генерация финальных изображений с face swap...",
                "images_generated": 0,
                "total_images": 0,
                "book_id": str(plot_result.book_id)  # Сохраняем book_id на всех этапах
            })
        
        logger.info(f"🎨 Шаг 7: Генерация финальных изображений для book_id={plot_result.book_id}")
        try:
            final_images_result = await _generate_final_images_internal(
                book_id=plot_result.book_id,
            db=db,
            current_user_id=user_id,
                final_style=style,
                face_url=face_url,
                task_id=task_id,
                child_photos=child_photos
        )
            logger.info(f"✅ Шаг 7 завершен: сгенерировано {len(final_images_result.get('images', []))} изображений")
        except Exception as e:
            logger.error(f"❌ Ошибка в Шаге 7: {str(e)}", exc_info=True)
            raise
        
        # Шаг 8: Генерация PDF
        if task_id:
            update_task_progress(task_id, {
                "stage": "generating_pdf",
                "current_step": 8,
                "total_steps": 8,
                "message": "Создание PDF файла...",
            })
        
        logger.info(f"📄 Шаг 8: Генерация PDF для book_id={plot_result.book_id}")
        
        # Преобразуем book_id в UUID
        from uuid import UUID as UUIDType
        book_uuid = UUIDType(plot_result.book_id)
        
        # Получаем книгу
        book = db.query(Book).filter(Book.id == book_uuid).first()
        if not book:
            raise HTTPException(status_code=404, detail="Книга не найдена")
        
        # Получаем стиль книги
        from ..models import ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_uuid).first()
        book_style = theme_style.final_style if theme_style else style
        
        # Получаем ребёнка для возраста
        child = db.query(Child).filter(Child.id == book.child_id).first()
        child_age = child.age if child else None
        
        # Получаем все сцены с финальными изображениями
        scenes = db.query(Scene).filter(Scene.book_id == book_uuid).order_by(Scene.order).all()
        
        # Создаем список страниц для PDF
        pages = []
        final_images_data = []
        
        for scene in scenes:
            # Получаем финальное изображение для сцены
            image_record = db.query(ImageModel).filter(
                ImageModel.book_id == book_uuid,
                ImageModel.scene_order == scene.order
            ).first()
            
            image_url = None
            if image_record and image_record.final_url:
                image_url = image_record.final_url
                final_images_data.append({
                    "order": scene.order,
                    "image_url": image_url
                })
            
            # Добавляем страницу в PDF (только если есть изображение)
            if image_url:
                # КРИТИЧНО: Используем ТОЛЬКО scene.text, НЕ short_summary и НЕ image_prompt
                # Для обложки (order=0) текст игнорируется - название рисуется программно
                scene_text = ""
                if scene.order != 0:  # Не обложка
                    scene_text = scene.text or ""  # ТОЛЬКО scene.text, без fallback на short_summary
                    # Очищаем текст от возможных промптов
                    if scene_text and ("Visual style" in scene_text or "IMPORTANT" in scene_text):
                        logger.warning(f"⚠️ Сцена {scene.order} содержит промпт в text, используем short_summary")
                        scene_text = scene.short_summary or ""
                
                pages.append(PdfPage(
                    order=scene.order,
                    text=scene_text,
                    image_url=image_url,
                    style=book_style,
                    age=child_age
                ))
        
        # Генерируем PDF
        if pages:
            pdf_dir = Path(BASE_UPLOAD_DIR) / "books" / str(book_uuid)
            pdf_dir.mkdir(parents=True, exist_ok=True)
            pdf_path = pdf_dir / "final.pdf"
            
            # Генерируем PDF в отдельном потоке (синхронная операция)
            await asyncio.to_thread(render_book_pdf, str(pdf_path), book.title or "StoryHero", pages, book_style, child_age)
            
            # Получаем публичный URL
            base_url = get_server_base_url()
            pdf_url = f"{base_url}/static/books/{book_uuid}/final.pdf"
            
            # Сохраняем в БД
            book.final_pdf_url = pdf_url
            book.images_final = {"images": final_images_data}
            db.commit()
            
            logger.info(f"✅ PDF создан: {pdf_url}")
        else:
            logger.warning(f"⚠️ Нет изображений для создания PDF")
        
        if task_id:
            update_task_progress(task_id, {
                "stage": "completed",
                "current_step": 8,
                "total_steps": 8,
                "message": "Книга успешно создана!",
                "book_id": plot_result.book_id,
                "pdf_url": book.final_pdf_url
            })
        
        logger.info(f"✅ Книга успешно создана: book_id={plot_result.book_id}")
        
        return {
            "book_id": plot_result.book_id,
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"❌ Ошибка в generate_full_book_task: {str(e)}", exc_info=True)
        if task_id:
            update_task_progress(task_id, {
                "stage": "error",
                "message": f"Ошибка: {str(e)}"
            })
        raise


@router.post("/generate_full_book")
async def generate_full_book_endpoint(
    data: GenerateFullBookRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерирует полную книгу асинхронно через задачу.
    
    Returns:
        dict: {"task_id": "...", "message": "..."}
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
        
    # Валидация темы (обязательное поле)
    if not data.theme or not data.theme.strip():
            raise HTTPException(
                status_code=400,
            detail="Тема книги обязательна. Пожалуйста, укажите, о чём будет книга."
            )
        
    # Преобразуем child_id в integer
    try:
        child_id_int = int(data.child_id)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Неверный формат child_id: {data.child_id}")
    
    # Получаем данные ребёнка
    child = db.query(Child).filter(Child.id == child_id_int).first()
    if not child:
        raise HTTPException(status_code=404, detail=f"Ребёнок с id={data.child_id} не найден")
    
    if child.user_id != user_id:
        raise HTTPException(status_code=403, detail="Доступ запрещён. Этот ребёнок принадлежит другому пользователю.")
        
    # Валидация num_pages
    if data.num_pages not in [10, 20]:
            raise HTTPException(
                status_code=400,
            detail="Количество страниц должно быть 10 или 20"
            )
        
    # Нормализация и валидация стиля
    normalized_style = normalize_style(data.style)
    if not is_style_known(normalized_style):
        raise HTTPException(
            status_code=400,
            detail=f"Неизвестный стиль: {data.style}. Доступные: {', '.join(ALL_STYLES)}"
        )
    
    # Проверка подписки для премиум-стилей
    deactivate_if_expired(db, user_id)
    if is_premium_style(normalized_style) and not check_style_access(db, user_id, normalized_style):
        raise HTTPException(
            status_code=403,
            detail="Этот стиль доступен только по подписке. Оформите подписку за 199 ₽/мес"
        )
    
    # Получаем фотографии ребёнка
    # КРИТИЧЕСКИ ВАЖНО: Используем ВСЕ фотографии для лучшего face swap!
    face_url = child.face_url or ""
    child_photos = []
    
    # Получаем все фотографии ребёнка через функцию из children.py
    from ..routers.children import _get_child_photos_urls
    try:
        child_photos = _get_child_photos_urls(child_id_int)
        logger.info(f"📸 Получено {len(child_photos)} фотографий ребёнка для face swap")
    except Exception as e:
        logger.warning(f"⚠️ Не удалось получить фотографии ребёнка: {str(e)}")
        child_photos = []
    
    # Проверяем, нет ли уже запущенной задачи для этого ребёнка
    from ..services.tasks import find_running_task
    existing_task = find_running_task({
        "type": "generate_full_book",
        "user_id": user_id,
        "child_id": str(child_id_int)
    })
    
    if existing_task:
        logger.warning(f"⚠️ generate_full_book: Уже есть активная задача {existing_task} для child_id={child_id_int}")
        return {
            "task_id": existing_task,
            "message": "Книга уже генерируется",
            "child_id": str(child_id_int)
        }
    
    # Создаём задачу
    meta = {
        "type": "generate_full_book",
        "user_id": user_id,
        "child_id": str(child_id_int)
    }
    
    task_id = create_task(
        generate_full_book_task,
        child.name,
        child.age,
        child.interests or [],
        child.fears or [],
        child.personality or "",
        child.moral or "",
        face_url,
        normalized_style,
        user_id,
        db,
        child_id=child_id_int,
        num_pages=data.num_pages,
        child_photos=child_photos,
        theme=data.theme.strip(),  # Передаём тему книги
        meta=meta,
        task_id=None
    )
    
    logger.info(f"✅ Задача генерации книги создана: task_id={task_id}, child_id={child_id_int}, theme={data.theme.strip()}")
    logger.warning(f"⚠️  ВАЖНО: Задача {task_id} запущена. Не перезапускайте контейнер до завершения генерации!")
    
    return {
        "task_id": task_id,
        "message": "Генерация книги запущена",
        "child_id": str(child_id_int),
        "warning": "⚠️ Не перезапускайте контейнер до завершения генерации!"
    }
