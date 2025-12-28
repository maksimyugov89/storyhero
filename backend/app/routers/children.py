"""
Роутер для работы с профилями детей.
"""
import logging
import os
from typing import List, Optional
from enum import Enum
from fastapi import APIRouter, HTTPException, Depends, UploadFile, File, Body
from sqlalchemy.orm import Session
from pydantic import BaseModel, Field, validator

from ..db import get_db
from ..models import Child
from ..core.deps import get_current_user
from ..services.local_file_service import BASE_UPLOAD_DIR
from ..services.storage import get_server_base_url

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/children", tags=["children"])


class ChildGender(str, Enum):
    """Пол ребенка"""
    MALE = "male"
    FEMALE = "female"


class ChildCreateRequest(BaseModel):
    name: str
    age: int
    gender: ChildGender = Field(..., description="Пол ребенка: 'male' или 'female'")
    interests: str = ""
    fears: str = ""
    character: str = ""
    moral: str = ""
    
    @validator('gender')
    def validate_gender(cls, v):
        if v not in ['male', 'female']:
            raise ValueError("Поле 'gender' должно быть 'male' или 'female'")
        return v


class ChildUpdateRequest(BaseModel):
    name: Optional[str] = None
    age: Optional[int] = None
    gender: Optional[ChildGender] = Field(None, description="Пол ребенка: 'male' или 'female'")
    interests: Optional[str] = None
    fears: Optional[str] = None
    character: Optional[str] = None
    moral: Optional[str] = None
    
    @validator('gender')
    def validate_gender(cls, v):
        if v is not None and v not in ['male', 'female']:
            raise ValueError("Поле 'gender' должно быть 'male' или 'female'")
        return v


class ChildResponse(BaseModel):
    id: str
    name: str
    age: int
    gender: str  # "male" или "female"
    interests: str
    fears: str
    character: str
    moral: str
    face_url: Optional[str] = None
    photos: List[str] = []


class ChildPhotoResponse(BaseModel):
    url: str
    filename: str
    is_avatar: bool = False


class ChildPhotosResponse(BaseModel):
    child_id: str
    photos: List[ChildPhotoResponse] = []


def _get_child_photos_urls(child_id: int) -> List[str]:
    """Получить список URL всех фотографий ребёнка."""
    photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id))
    photos = []
    
    if os.path.exists(photos_dir):
        base_url = get_server_base_url()
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        for filename in sorted(os.listdir(photos_dir)):
            if filename.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                photo_url = f"{base_url}/static/children/{child_id}/{filename}"
                photos.append(photo_url)
                # Используем ВСЕ фотографии для лучшего face swap - без ограничений
    
    return photos


@router.get("", response_model=List[ChildResponse], response_model_exclude_unset=False)
def list_children(
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить список всех детей текущего пользователя."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    children = db.query(Child).filter(Child.user_id == user_id).all()
    
    result = []
    for child in children:
        photos_urls = _get_child_photos_urls(child.id)
        result.append(ChildResponse(
            id=str(child.id),
            name=child.name,
            age=child.age,
            gender=child.gender or "male",  # Fallback для старых записей
            interests=", ".join(child.interests) if isinstance(child.interests, list) else (child.interests or ""),
            fears=", ".join(child.fears) if isinstance(child.fears, list) else (child.fears or ""),
            character=child.personality or "",
            moral=child.moral or "",
            face_url=child.face_url,
            photos=photos_urls
        ))
    
    return result


@router.get("/{child_id}", response_model=ChildResponse, response_model_exclude_unset=False)
def get_child(
    child_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить профиль конкретного ребёнка."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    child = db.query(Child).filter(
        Child.id == child_id,
        Child.user_id == user_id
    ).first()
    
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
    
    photos_urls = _get_child_photos_urls(child.id)
    
    return ChildResponse(
            id=str(child.id),
            name=child.name,
            age=child.age,
            gender=child.gender or "male",  # Fallback для старых записей
            interests=", ".join(child.interests) if isinstance(child.interests, list) else (child.interests or ""),
            fears=", ".join(child.fears) if isinstance(child.fears, list) else (child.fears or ""),
            character=child.personality or "",
            moral=child.moral or "",
            face_url=child.face_url,
            photos=photos_urls
        )


@router.post("", response_model=ChildResponse)
def create_child(
    data: ChildCreateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Создать нового ребёнка."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    # Преобразуем Enum в строку для SQLAlchemy
    # Pydantic автоматически преобразует строку в Enum, но SQLAlchemy нужна строка
    if isinstance(data.gender, ChildGender):
        gender_value = data.gender.value
    elif isinstance(data.gender, str):
        gender_value = data.gender
    else:
        # Fallback: пытаемся получить значение
        gender_value = getattr(data.gender, 'value', str(data.gender))
    
    logger.info(f"📝 Создание ребенка: name={data.name}, age={data.age}, gender={gender_value} (тип входного: {type(data.gender)})")
    
    # Создаем объект Child БЕЗ gender сначала
    child = Child(
        user_id=user_id,
        name=data.name,
        age=data.age,
        interests=data.interests.split(", ") if data.interests else [],
        fears=data.fears.split(", ") if data.fears else [],
        personality=data.character,
        moral=data.moral
    )
    
    # КРИТИЧНО: Устанавливаем gender ПОСЛЕ создания объекта, чтобы SQLAlchemy точно его увидел
    child.gender = gender_value
    
    logger.info(f"📝 Child объект создан: gender={child.gender} (тип: {type(child.gender)}, значение: {repr(child.gender)})")
    
    # Проверяем, что gender установлен перед добавлением в сессию
    if not child.gender:
        logger.error(f"❌ КРИТИЧНО: gender не установлен! child.gender={child.gender}, gender_value={gender_value}")
        raise HTTPException(status_code=500, detail="Ошибка: поле gender не установлено")
    
    db.add(child)
    db.commit()
    db.refresh(child)
    
    # Получаем URL фотографий (пока пустой список, так как фото еще не загружены)
    photos_urls = _get_child_photos_urls(child.id)
    
    return ChildResponse(
        id=str(child.id),
        name=child.name,
        age=child.age,
        gender=child.gender,
        interests=", ".join(child.interests) if isinstance(child.interests, list) else (child.interests or ""),
        fears=", ".join(child.fears) if isinstance(child.fears, list) else (child.fears or ""),
        character=child.personality or "",
        moral=child.moral or "",
        face_url=child.face_url,
        photos=photos_urls
    )


@router.put("/{child_id}", response_model=ChildResponse)
def update_child(
    child_id: int,
    data: ChildUpdateRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Обновить анкету ребёнка.
    
    Принимает те же поля, что и ChildCreateRequest, все опциональные:
    name, age, interests, fears, character, moral, face_url.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")

    child = (
        db.query(Child)
        .filter(Child.id == child_id, Child.user_id == user_id)
        .first()
    )
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")

    # Обновляем только переданные поля
    if data.name is not None:
        child.name = data.name
    if data.age is not None:
        child.age = data.age
    if data.gender is not None:
        child.gender = data.gender.value  # Используем .value для получения строки из Enum
    if data.interests is not None:
        child.interests = data.interests.split(", ") if data.interests else []
    if data.fears is not None:
        child.fears = data.fears.split(", ") if data.fears else []
    if data.character is not None:
        child.personality = data.character
    if data.moral is not None:
        child.moral = data.moral
    if data.face_url is not None:
        child.face_url = data.face_url

    db.commit()
    db.refresh(child)

    photos_urls = _get_child_photos_urls(child.id)

    return ChildResponse(
        id=str(child.id),
        name=child.name,
        age=child.age,
        gender=child.gender or "male",  # Fallback для старых записей
        interests=", ".join(child.interests) if isinstance(child.interests, list) else (child.interests or ""),
        fears=", ".join(child.fears) if isinstance(child.fears, list) else (child.fears or ""),
        character=child.personality or "",
        moral=child.moral or "",
        face_url=child.face_url,
        photos=photos_urls,
    )
    
    return ChildResponse(
        id=str(child.id),
        name=child.name,
        age=child.age,
        interests=data.interests,
        fears=data.fears,
        character=data.character,
        moral=data.moral,
        face_url=None,
        photos=[]
    )


@router.post("/{child_id}/photos")
async def upload_child_photo(
    child_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Загрузить фотографию ребёнка."""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    child = db.query(Child).filter(
        Child.id == child_id,
        Child.user_id == user_id
    ).first()
    
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
        
    # Сохраняем файл
    photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id))
    os.makedirs(photos_dir, exist_ok=True)
    
    import uuid
    unique_filename = f"{uuid.uuid4()}.jpg"
    file_path = os.path.join(photos_dir, unique_filename)
    
    with open(file_path, "wb") as f:
        content = await file.read()
        f.write(content)
    
    # Формируем URL
    base_url = get_server_base_url()
    if ":8000" in base_url:
        base_url = base_url.replace(":8000", "")
    
    photo_url = f"{base_url}/static/children/{child_id}/{unique_filename}"
    
    # Обновляем face_url, если это первое фото
    if not child.face_url:
        child.face_url = photo_url
        db.commit()
    
    return {
        "child_id": str(child_id),
        "face_url": photo_url,
        "message": "Фотография успешно загружена"
    }
    
    
@router.get("/{child_id}/photos", response_model=ChildPhotosResponse)
def get_child_photos(
    child_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Получить список фотографий ребёнка.
    
    Формат ответа соответствует Flutter-модели ChildPhotosResponse:
    {
      "child_id": "1",
        "photos": [
        {"url": "...", "filename": "...", "is_avatar": false}
        ]
    }
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    # Проверяем, что ребёнок принадлежит текущему пользователю
    child = (
        db.query(Child)
        .filter(Child.id == child_id, Child.user_id == user_id)
        .first()
    )
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
    
    # Собираем список файлов
    photos_dir = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id))
    photos: List[ChildPhotoResponse] = []
    
    if os.path.exists(photos_dir):
        base_url = get_server_base_url()
        if ":8000" in base_url:
            base_url = base_url.replace(":8000", "")
        
        for filename in sorted(os.listdir(photos_dir)):
            if not filename.lower().endswith((".jpg", ".jpeg", ".png", ".webp")):
                continue
            
            photo_url = f"{base_url}/static/children/{child_id}/{filename}"
            is_avatar = bool(child.face_url and child.face_url.endswith(f"/{filename}"))

            photos.append(
                ChildPhotoResponse(
                    url=photo_url,
                    filename=filename,
                    is_avatar=is_avatar,
                )
            )

            if len(photos) >= 5:
                break

    return ChildPhotosResponse(child_id=str(child_id), photos=photos)


class DeletePhotoRequest(BaseModel):
    photo_url: str


@router.delete("/{child_id}/photos")
def delete_child_photo(
    child_id: int,
    data: DeletePhotoRequest = Body(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Удалить фотографию ребёнка.
    
    Принимает JSON: { "photo_url": "https://storyhero.ru/static/children/1/xxx.jpg" }
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    # Проверяем, что ребёнок принадлежит пользователю
    child = (
        db.query(Child)
        .filter(Child.id == child_id, Child.user_id == user_id)
        .first()
    )
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")

    photo_url = data.photo_url.strip()
    if not photo_url:
        raise HTTPException(status_code=400, detail="photo_url обязателен")

    # Преобразуем URL в путь к файлу
    # Ожидаемый формат: https://storyhero.ru/static/children/{child_id}/{filename}
    try:
        from urllib.parse import urlparse

        parsed = urlparse(photo_url)
        path = parsed.path  # /static/children/{child_id}/{filename}
    except Exception:
        raise HTTPException(status_code=400, detail="Некорректный формат photo_url")

    expected_prefix = f"/static/children/{child_id}/"
    if not path.startswith(expected_prefix):
        raise HTTPException(
            status_code=400,
            detail="photo_url не принадлежит этому ребёнку",
        )

    filename = path.split("/")[-1]
    file_path = os.path.join(BASE_UPLOAD_DIR, "children", str(child_id), filename)

    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Файл не найден")

    # Удаляем файл
    try:
        os.remove(file_path)
    except Exception as e:
        logger.error(f"Ошибка удаления файла {file_path}: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail="Не удалось удалить файл")

    # Если это был avatar, сбрасываем face_url
    if child.face_url == photo_url:
        child.face_url = None
        db.commit()

    return {"status": "ok"}


class SetAvatarRequest(BaseModel):
    photo_url: str


@router.put("/{child_id}/photos/avatar")
def set_child_avatar(
    child_id: int,
    data: SetAvatarRequest = Body(...),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    """
    Установить главное фото (avatar) для ребёнка.
    
    Принимает JSON: { "photo_url": "https://storyhero.ru/static/children/1/xxx.jpg" }
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")

    child = (
        db.query(Child)
        .filter(Child.id == child_id, Child.user_id == user_id)
        .first()
    )
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")

    photo_url = data.photo_url.strip()
    if not photo_url:
        raise HTTPException(status_code=400, detail="photo_url обязателен")
        
    # Проверяем, что avatar действительно из папки этого ребёнка
    from urllib.parse import urlparse

    parsed = urlparse(photo_url)
    path = parsed.path  # /static/children/{child_id}/{filename}
    expected_prefix = f"/static/children/{child_id}/"
    if not path.startswith(expected_prefix):
        raise HTTPException(
            status_code=400,
            detail="photo_url не принадлежит этому ребёнку",
        )

    # Просто обновляем face_url
    child.face_url = photo_url
    db.commit()

    return {"status": "ok", "face_url": photo_url}


# ============================================================================
# FACE PROFILE ENDPOINTS
# ============================================================================

from ..models.child_face_profile import ChildFaceProfile
from ..schemas.face_profile import (
    CreateFaceProfileRequest,
    FaceProfileResponse,
    FaceProfileStatusResponse,
)
from ..services.face_service import build_face_profile
import numpy as np


@router.post("/{child_id}/face-profile", response_model=FaceProfileResponse)
async def create_face_profile(
    child_id: int,
    data: CreateFaceProfileRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Создать face profile для ребёнка из фотографий.
    
    Требования:
    - Минимум 3 валидных лица из предоставленных фотографий
    - Создаёт reference.png и сохраняет embedding в БД
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    # Проверяем, что ребёнок принадлежит пользователю
    child = db.query(Child).filter(
        Child.id == child_id,
        Child.user_id == user_id
    ).first()
    
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
    
    # Проверяем, что есть фотографии
    if not data.photo_paths or len(data.photo_paths) < 3:
        raise HTTPException(
            status_code=400,
            detail="Требуется минимум 3 фотографии для создания face profile"
        )
    
    try:
        # Создаём face profile
        profile_data = build_face_profile(data.photo_paths, child_id)
        
        # Сохраняем или обновляем запись в БД
        existing_profile = db.query(ChildFaceProfile).filter(
            ChildFaceProfile.child_id == child_id
        ).first()
        
        if existing_profile:
            # Обновляем существующий профиль
            existing_profile.embedding = profile_data["mean_embedding_bytes"]
            existing_profile.reference_image_path = profile_data["reference_rel_path"]
            db.commit()
            db.refresh(existing_profile)
            
            logger.info(f"✓ Face profile обновлён для child_id={child_id}")
            
            return FaceProfileResponse(
                child_id=child_id,
                reference_image_url=profile_data["reference_public_url"],
                embedding_saved=True,
                valid_faces=profile_data["valid_faces"],
                used_faces=profile_data["used_faces"],
                threshold=0.60,
                created_at=existing_profile.created_at,
                updated_at=existing_profile.updated_at
            )
        else:
            # Создаём новый профиль
            new_profile = ChildFaceProfile(
                child_id=child_id,
                embedding=profile_data["mean_embedding_bytes"],
                reference_image_path=profile_data["reference_rel_path"]
            )
            db.add(new_profile)
            db.commit()
            db.refresh(new_profile)
            
            logger.info(f"✓ Face profile создан для child_id={child_id}")
            
            return FaceProfileResponse(
                child_id=child_id,
                reference_image_url=profile_data["reference_public_url"],
                embedding_saved=True,
                valid_faces=profile_data["valid_faces"],
                used_faces=profile_data["used_faces"],
                threshold=0.60,
                created_at=new_profile.created_at,
                updated_at=new_profile.updated_at
            )
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"❌ Ошибка при создании face profile: {e}", exc_info=True)
        db.rollback()
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при создании face profile: {str(e)}"
        )


@router.get("/{child_id}/face-profile", response_model=FaceProfileStatusResponse)
def get_face_profile_status(
    child_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить статус face profile для ребёнка.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid user token")
    
    # Проверяем, что ребёнок принадлежит пользователю
    child = db.query(Child).filter(
        Child.id == child_id,
        Child.user_id == user_id
    ).first()
    
    if not child:
        raise HTTPException(status_code=404, detail="Ребёнок не найден")
    
    # Ищем face profile
    profile = db.query(ChildFaceProfile).filter(
        ChildFaceProfile.child_id == child_id
    ).first()
    
    if not profile:
        return FaceProfileStatusResponse(exists=False)
    
    # Формируем публичный URL
    from ..services.storage import get_server_base_url
    base_url = get_server_base_url()
    if ":8000" in base_url:
        base_url = base_url.replace(":8000", "")
    reference_public_url = f"{base_url}/static/{profile.reference_image_path}"
    
    return FaceProfileStatusResponse(
        exists=True,
        reference_image_url=reference_public_url,
        created_at=profile.created_at,
        updated_at=profile.updated_at
    )



