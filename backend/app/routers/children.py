import logging
import os
import shutil
from typing import List, Optional
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Child, Book
from ..schemas.book import BookOut
# Удалено: больше не используем Supabase
from ..services.local_file_service import upload_child_photo as upload_child_photo_service, BASE_UPLOAD_DIR
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/children", tags=["children"])


class ChildCreateRequest(BaseModel):
    """Запрос на создание ребёнка - формат Flutter"""
    name: str
    age: int
    interests: str  # Строка через запятую
    fears: str  # Строка
    character: str  # Строка
    moral: str
    face_url: Optional[str] = None  # URL фотографии (опционально)


class ChildCreateResponse(BaseModel):
    """Ответ при создании ребёнка"""
    status: str
    child_id: str  # UUID


class ChildResponse(BaseModel):
    """Формат ответа для GET запросов - соответствует формату Flutter"""
    id: str
    name: str
    age: int
    interests: str
    fears: str
    character: str
    moral: str
    face_url: Optional[str] = None  # URL фотографии (опционально)


class ChildUpdate(BaseModel):
    """Модель для обновления ребёнка - все поля опциональные"""
    name: Optional[str] = None
    age: Optional[int] = None
    interests: Optional[str] = None
    fears: Optional[str] = None
    character: Optional[str] = None
    moral: Optional[str] = None
    face_url: Optional[str] = None


class AvatarRequest(BaseModel):
    """Запрос на установку аватарки"""
    photo_url: str


@router.post("", response_model=ChildCreateResponse)
def create_child(
    data: ChildCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создать ребёнка в локальной базе данных (PostgreSQL).
    
    Принимает данные в формате Flutter:
    - name: строка
    - age: число
    - interests: строка через запятую
    - fears: строка
    - character: строка
    - moral: строка
    - face_url: опциональный URL фотографии
    
    Возвращает:
    - status: "ok"
    - child_id: Integer ID созданного ребёнка
    """
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    try:
        # Преобразуем строки interests и fears в списки (JSON)
        interests_list = [item.strip() for item in data.interests.split(",")] if data.interests else []
        fears_list = [item.strip() for item in data.fears.split(",")] if data.fears else []
        
        # Создаем запись в локальной БД
        child = Child(
            name=data.name,
            age=data.age,
            interests=interests_list,
            fears=fears_list,
            personality=data.character,  # character -> personality
            moral=data.moral,
            user_id=user_id,  # Сохраняем user_id для приватности
            face_url=data.face_url  # Сохраняем face_url
        )
        
        db.add(child)
        db.commit()
        db.refresh(child)
        
        return ChildCreateResponse(
            status="ok",
            child_id=str(child.id)  # Integer ID преобразуем в строку
        )
        
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка БД: {str(e)}",
        )


@router.get("", response_model=List[ChildResponse])
def list_children(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить список детей текущего пользователя из локальной базы данных (PostgreSQL).
    
    Возвращает только детей, принадлежащих текущему пользователю (фильтрация по user_id).
    Формат ответа для Flutter:
    - id: Integer (преобразуется в строку)
    - name: строка
    - age: число
    - interests: строка (из JSON)
    - fears: строка (из JSON)
    - character: строка (из personality)
    - moral: строка
    - face_url: URL фотографии (если есть)
    """
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token: missing user ID")
    
    try:
        # Получаем только детей текущего пользователя, сортировка по created_at (новые сначала)
        children = db.query(Child).filter(Child.user_id == user_id).order_by(Child.created_at.desc()).all()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при получении списка детей из базы данных: {str(e)}",
        )
    
    # Преобразуем данные из модели Child в формат ChildResponse
    # Гарантируем, что все поля - строки (как ожидает Flutter)
    formatted_children = []
    for child in children:
        # Преобразуем JSON поля в строки
        interests_str = ""
        if child.interests:
            if isinstance(child.interests, list):
                interests_str = ", ".join(str(item) for item in child.interests)
            elif isinstance(child.interests, dict):
                interests_str = ", ".join(f"{k}: {v}" for k, v in child.interests.items())
            else:
                interests_str = str(child.interests)
        
        fears_str = ""
        if child.fears:
            if isinstance(child.fears, list):
                fears_str = ", ".join(str(item) for item in child.fears)
            elif isinstance(child.fears, dict):
                fears_str = ", ".join(f"{k}: {v}" for k, v in child.fears.items())
            else:
                fears_str = str(child.fears)
        
        formatted_children.append(ChildResponse(
            id=str(child.id),
            name=str(child.name),
            age=int(child.age),
            interests=interests_str,
            fears=fears_str,
            character=str(child.personality) if child.personality else "",
            moral=str(child.moral) if child.moral else "",
            face_url=child.face_url if child.face_url else None  # Используем face_url из модели
        ))
    
    return formatted_children


@router.get("/{child_id}", response_model=ChildResponse)
def get_child(
    child_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить одного ребёнка по ID из локальной БД.
    
    Возвращает данные в формате, который ожидает Flutter.
    
    ВАЛИДАЦИЯ:
    - Проверяет формат child_id (должен быть числом)
    - Проверяет существование ребёнка
    - Проверяет права доступа (ребёнок принадлежит пользователю)
    
    Returns:
        ChildResponse: Данные ребёнка
        
    Raises:
        400: Неверный формат child_id
        401: Не авторизован
        403: Нет прав доступа
        404: Ребёнок не найден
        500: Внутренняя ошибка сервера
    """
    # Валидация child_id
    if not child_id or not child_id.strip():
        raise HTTPException(
            status_code=400,
            detail="Не указан ID ребёнка (child_id)"
        )
    
    try:
        child_id_int = int(child_id)
        if child_id_int <= 0:
            raise ValueError("child_id должен быть положительным числом")
    except (ValueError, TypeError):
        logger.error(f"❌ get_child: Неверный формат child_id: '{child_id}'")
        raise HTTPException(
            status_code=400,
            detail=f"Неверный формат ID ребёнка: '{child_id}'. Ожидается положительное число."
        )
    
    # Проверка авторизации
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="Требуется авторизация"
        )
    
    try:
        child = db.query(Child).filter(Child.id == child_id_int).first()
        if not child:
            logger.warning(f"⚠️ get_child: Ребёнок с ID {child_id_int} не найден")
            raise HTTPException(
                status_code=404,
                detail=f"Ребёнок с ID {child_id_int} не найден"
            )
        
        # Проверяем права доступа
        if child.user_id != user_id:
            logger.warning(f"⚠️ get_child: Попытка доступа к ребёнку {child_id_int} другого пользователя")
            raise HTTPException(
                status_code=403,
                detail="Нет прав доступа. Этот ребёнок принадлежит другому пользователю."
            )
        
        # Преобразуем в формат ChildResponse
        return ChildResponse(
            id=str(child.id),
            name=child.name,
            age=child.age,
            interests=child.interests or "",
            fears=child.fears or "",
            character=child.personality or "",
            moral=child.moral or "",
            face_url=child.face_url
        )
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ get_child: Неожиданная ошибка при получении ребёнка {child_id_int}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Внутренняя ошибка сервера при получении ребёнка: {str(e)}"
        )


@router.get("/{child_id}/books", response_model=List[BookOut])
def get_child_books(
    child_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить все книги для конкретного ребёнка.
    
    ВАЛИДАЦИЯ:
    - Проверяет формат child_id (должен быть числом)
    - Проверяет существование ребёнка
    - Проверяет права доступа (ребёнок принадлежит пользователю)
    
    Returns:
        List[BookOut]: Список книг ребёнка
        
    Raises:
        400: Неверный формат child_id
        401: Не авторизован
        403: Нет прав доступа
        404: Ребёнок не найден
        500: Внутренняя ошибка сервера
    """
    # Валидация child_id
    if not child_id or not child_id.strip():
        raise HTTPException(
            status_code=400,
            detail="Не указан ID ребёнка (child_id)"
        )
    
    try:
        child_id_int = int(child_id)
        if child_id_int <= 0:
            raise ValueError("child_id должен быть положительным числом")
    except (ValueError, TypeError):
        logger.error(f"❌ get_child_books: Неверный формат child_id: '{child_id}'")
        raise HTTPException(
            status_code=400,
            detail=f"Неверный формат ID ребёнка: '{child_id}'. Ожидается положительное число."
        )
    
    # Проверка авторизации
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(
            status_code=401,
            detail="Требуется авторизация"
        )
    
    try:
        # Проверяем существование ребёнка и права доступа
        child = db.query(Child).filter(Child.id == child_id_int).first()
        if not child:
            logger.warning(f"⚠️ get_child_books: Ребёнок с ID {child_id_int} не найден")
            raise HTTPException(
                status_code=404,
                detail=f"Ребёнок с ID {child_id_int} не найден"
            )
        
        if child.user_id != user_id:
            logger.warning(f"⚠️ get_child_books: Попытка доступа к ребёнку {child_id_int} другого пользователя")
            raise HTTPException(
                status_code=403,
                detail="Нет прав доступа. Этот ребёнок принадлежит другому пользователю."
            )
        
        # Получаем все книги для этого ребёнка, принадлежащие пользователю
        books = db.query(Book).filter(
            Book.child_id == child_id_int,
            Book.user_id == user_id
        ).order_by(Book.created_at.desc()).all()
        
        logger.info(f"✅ get_child_books: Найдено {len(books)} книг для child_id={child_id_int}")
        return books
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ get_child_books: Неожиданная ошибка при получении книг для child_id={child_id_int}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Внутренняя ошибка сервера при получении книг: {str(e)}"
        )


@router.put("/{child_id}", response_model=ChildResponse)
def update_child(
    child_id: str,
    child_update: ChildUpdate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Обновить данные ребёнка по ID в локальной БД.
    
    Принимает только изменённые поля (все опциональные).
    """
    user_id = current_user.get("sub") or current_user.get("id")
    
    # Проверяем, что ребёнок существует и принадлежит пользователю
    try:
        child = db.query(Child).filter(Child.id == int(child_id)).first()
        if not child:
            raise HTTPException(status_code=404, detail="Ребёнок не найден")
        
        if child.user_id != user_id:
            raise HTTPException(status_code=403, detail="Доступ запрещён")
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат child_id")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при проверке существования ребёнка: {str(e)}",
        )

    # Обновляем только переданные поля
    if child_update.name is not None:
        child.name = child_update.name
    if child_update.age is not None:
        child.age = child_update.age
    if child_update.interests is not None:
        # Преобразуем строку в список, если нужно
        if isinstance(child_update.interests, str):
            child.interests = [item.strip() for item in child_update.interests.split(",") if item.strip()]
        else:
            child.interests = child_update.interests
    if child_update.fears is not None:
        # Преобразуем строку в список, если нужно
        if isinstance(child_update.fears, str):
            child.fears = [item.strip() for item in child_update.fears.split(",") if item.strip()]
        else:
            child.fears = child_update.fears
    if child_update.character is not None:
        child.personality = child_update.character  # character -> personality
    if child_update.moral is not None:
        child.moral = child_update.moral
    if child_update.face_url is not None:
        child.face_url = child_update.face_url

    try:
        db.commit()
        db.refresh(child)
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при обновлении ребёнка: {str(e)}",
        )
    
    # Преобразуем в формат ChildResponse
    interests_str = ""
    if child.interests:
        if isinstance(child.interests, list):
            interests_str = ", ".join(str(item) for item in child.interests)
        else:
            interests_str = str(child.interests)
    
    fears_str = ""
    if child.fears:
        if isinstance(child.fears, list):
            fears_str = ", ".join(str(item) for item in child.fears)
        else:
            fears_str = str(child.fears)
    
    return ChildResponse(
        id=str(child.id),
        name=str(child.name),
        age=int(child.age),
        interests=interests_str,
        fears=fears_str,
        character=str(child.personality) if child.personality else "",
        moral=str(child.moral) if child.moral else "",
        face_url=child.face_url if child.face_url else None
    )


@router.post("/{child_id}/photos")
async def upload_child_photo(
    child_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Загрузить фотографию ребёнка и сохранить URL в базе данных.
    
    Endpoint: POST /children/{child_id}/photos
    
    Принимает:
    - child_id: ID ребёнка (Integer)
    - file: файл изображения через multipart/form-data (поле 'file')
    
    Требования:
    - Формат: JPEG, PNG, WebP
    - Максимальный размер: 10MB
    - Требуется авторизация (Bearer token)
    
    Сохраняет фотографию локально в /var/www/storyhero/uploads/children/<child_id>/<filename>
    и обновляет поле face_url в таблице children.
    
    Returns:
    {
        "child_id": "<id>",
        "face_url": "http://.../static/children/<child_id>/<filename>",
        "message": "Фотография успешно загружена"
    }
    """
    logger.info("=" * 70)
    logger.info(f"📸 НАЧАЛО ЗАГРУЗКИ ФОТО ДЛЯ РЕБЁНКА {child_id}")
    logger.info(f"   Пользователь: {current_user.get('sub') or current_user.get('id', 'unknown')}")
    logger.info(f"   Файл: {file.filename}")
    logger.info(f"   Content-Type: {file.content_type}")
    
    user_id = current_user.get("sub") or current_user.get("id")
    
    # Шаг 1: Проверяем, что ребёнок существует и принадлежит пользователю
    logger.info(f"   [1/3] Проверка существования ребёнка {child_id} в локальной БД...")
    try:
        child = db.query(Child).filter(Child.id == int(child_id)).first()
        if not child:
            logger.warning(f"   ✗ Ребёнок с ID {child_id} не найден в базе данных")
            raise HTTPException(
                status_code=404,
                detail=f"Ребёнок с ID {child_id} не найден"
            )
        
        # Проверяем, что ребёнок принадлежит текущему пользователю
        if child.user_id != user_id:
            logger.warning(f"   ✗ Доступ запрещён: ребёнок принадлежит другому пользователю")
            raise HTTPException(
                status_code=403,
                detail="Доступ запрещён"
            )
        
        logger.info(f"   ✓ Ребёнок найден: {child.name} (ID: {child_id})")
    except HTTPException:
        raise
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат child_id")
    except Exception as e:
        logger.error(f"   ✗ Ошибка при проверке существования ребёнка {child_id}: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при проверке существования ребёнка: {str(e)}",
        )
    
    # Шаг 2: Загружаем файл через локальный сервис
    logger.info(f"   [2/3] Загрузка файла через локальный сервис...")
    logger.info(f"        Путь сохранения: /var/www/storyhero/uploads/children/{child_id}/")
    try:
        public_url = await upload_child_photo_service(file, child_id)
        logger.info(f"   ✓ Файл успешно сохранён")
        logger.info(f"   ✓ Публичный URL: {public_url}")
    except HTTPException as e:
        logger.error(f"   ✗ Ошибка при загрузке файла: {e.detail}")
        raise
    except Exception as e:
        logger.error(f"   ✗ Непредвиденная ошибка при загрузке файла: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при загрузке фотографии: {str(e)}"
        )
    
    # Шаг 3: Обновляем запись ребёнка с URL фотографии в локальной БД
    logger.info(f"   [3/3] Обновление записи ребёнка в локальной БД (face_url)...")
    try:
        child.face_url = public_url
        db.commit()
        db.refresh(child)
        logger.info(f"   ✓ Запись успешно обновлена")
        logger.info(f"   ✓ Новый face_url: {child.face_url}")
    except Exception as e:
        db.rollback()
        logger.error(f"   ✗ Ошибка при обновлении face_url: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Фотография загружена, но не удалось сохранить URL в базе данных: {str(e)}"
        )
    
    # Формируем ответ
    response = {
        "child_id": str(child_id),
        "face_url": public_url,
        "message": "Фотография успешно загружена"
    }
    
    logger.info(f"   ✓ УСПЕШНО: Загрузка завершена для ребёнка {child_id}")
    logger.info(f"   Ответ: {response}")
    logger.info("=" * 70)
    
    return response


@router.get("/{child_id}/photos")
def get_child_photos(
    child_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить список всех фотографий ребёнка.
    
    Endpoint: GET /children/{child_id}/photos
    
    Returns:
    {
        "child_id": "<id>",
        "photos": [
            {
                "url": "http://.../static/children/<child_id>/<filename>",
                "filename": "<filename>",
                "is_avatar": true/false
            },
            ...
        ]
    }
    """
    import os
    from ..services.local_file_service import BASE_UPLOAD_DIR, get_server_base_url
    
    user_id = current_user.get("sub") or current_user.get("id")
    
    # Проверяем, что ребёнок существует и принадлежит пользователю
    try:
        child = db.query(Child).filter(Child.id == int(child_id)).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с ID {child_id} не найден")
        
        if child.user_id != user_id:
            raise HTTPException(status_code=403, detail="Доступ запрещён")
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат child_id")
    except HTTPException:
        raise
    
    # Получаем список файлов из директории
    photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id))
    photos = []  # ВСЕГДА массив, никогда null
    
    if os.path.exists(photos_dir):
        base_url = get_server_base_url()
        current_avatar = child.face_url or ""
        
        for filename in sorted(os.listdir(photos_dir)):  # Сортируем для стабильности
            if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                photo_url = f"{base_url}/static/children/{child_id}/{filename}"
                is_avatar = (photo_url == current_avatar)
                photos.append({
                    "url": photo_url,
                    "filename": filename,
                    "is_avatar": is_avatar
                })
    
    # ВАЖНО: Ограничиваем до 5 фото (максимум) и ВСЕГДА возвращаем массив
    photos = photos[:5]  # Максимум 5 фото
    
    return {
        "child_id": str(child_id),
        "photos": photos  # ВСЕГДА массив, даже если пустой
    }


class AvatarRequest(BaseModel):
    photo_url: str


@router.put("/{child_id}/photos/avatar")
def set_child_avatar(
    child_id: str,
    data: AvatarRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Установить фотографию как аватарку ребёнка.
    
    Endpoint: PUT /children/{child_id}/photos/avatar
    
    Body (JSON):
    {
        "photo_url": "http://.../static/children/<child_id>/<filename>"
    }
    
    Returns:
    {
        "child_id": "<id>",
        "face_url": "<photo_url>",
        "message": "Аватарка успешно установлена"
    }
    """
    user_id = current_user.get("sub") or current_user.get("id")
    photo_url = data.photo_url
    
    # Проверяем, что ребёнок существует и принадлежит пользователю
    try:
        child = db.query(Child).filter(Child.id == int(child_id)).first()
        if not child:
            raise HTTPException(status_code=404, detail=f"Ребёнок с ID {child_id} не найден")
        
        if child.user_id != user_id:
            raise HTTPException(status_code=403, detail="Доступ запрещён")
    except ValueError:
        raise HTTPException(status_code=400, detail="Неверный формат child_id")
    except HTTPException:
        raise
    
    # Проверяем, что URL принадлежит этому ребёнку
    if f"/children/{child_id}/" not in photo_url:
        raise HTTPException(status_code=400, detail="URL фотографии не принадлежит этому ребёнку")
    
    # Обновляем face_url
    try:
        child.face_url = photo_url
        db.commit()
        db.refresh(child)
        
        return {
            "child_id": str(child_id),
            "face_url": photo_url,
            "message": "Аватарка успешно установлена"
        }
    except Exception as e:
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при установке аватарки: {str(e)}"
        )


@router.delete("/{child_id}", status_code=204)
def delete_child(
    child_id: str,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Удалить ребёнка по ID из локальной базы данных.
    
    Требуется авторизация. Пользователь может удалять только своих детей.
    При удалении ребёнка также удаляются:
    - Все связанные книги (каскадное удаление через CASCADE)
    - Все фотографии ребёнка на диске
    
    Args:
        child_id: ID ребёнка (Integer как строка)
        
    Returns:
        204 No Content - при успешном удалении
        
    Raises:
        HTTPException 401: Если не авторизован
        HTTPException 403: Если нет прав на удаление (ребёнок принадлежит другому пользователю)
        HTTPException 404: Если ребёнок не найден
        HTTPException 500: При внутренней ошибке сервера
    """
    # Извлекаем user_id из токена
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Требуется авторизация")
    
    try:
        # Преобразуем child_id в integer
        try:
            child_id_int = int(child_id)
        except ValueError:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Неверный формат child_id"
            )
        
        # Найти ребёнка в локальной БД
        child = db.query(Child).filter(Child.id == child_id_int).first()
        
        if not child:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Ребёнок не найден"
            )
        
        # Проверить права доступа
        if child.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Нет прав на удаление этого ребёнка"
            )
        
        # Логируем операцию удаления
        logger.info(f"Удаление ребёнка {child_id} (ID: {child_id_int}, имя: {child.name}) пользователем {user_id}")
        
        # Удаляем фотографии ребёнка с диска
        photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id_int))
        if os.path.exists(photos_dir):
            try:
                shutil.rmtree(photos_dir)
                logger.info(f"Удалена директория с фотографиями: {photos_dir}")
            except Exception as e:
                # Не критично, если директорию не удалось удалить
                logger.warning(f"Не удалось удалить директорию {photos_dir}: {str(e)}")
        
        # Удаление связанных книг происходит автоматически через CASCADE
        # Book удалятся автоматически благодаря ondelete="CASCADE" в модели Book
        
        # Удаляем ребёнка из БД
        db.delete(child)
        db.commit()
        
        logger.info(f"Ребёнок {child_id_int} успешно удалён")
        
        # 204 No Content - пустое тело ответа
        return None
        
    except HTTPException:
        # Пробрасываем HTTP исключения как есть
        raise
    except Exception as e:
        db.rollback()
        logger.error(f"Ошибка при удалении ребёнка {child_id}: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Внутренняя ошибка сервера"
        )
