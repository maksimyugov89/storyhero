"""
Роутер для редактирования книг (синхронизировано с Flutter):
- Редактирование текста сцен (до 5 вариантов, variant_number 0-5, где 0 = оригинал)
- Редактирование изображений (до 3 вариантов, variant_number 0-3, где 0 = оригинал)
- Выбор версий
- Финальный рендеринг
"""
import logging
import uuid as uuid_module
import requests
from pathlib import Path
from typing import List, Optional
from uuid import UUID
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import and_, func
from pydantic import BaseModel

from ..db import get_db
from ..models import Book, Scene, Image, TextVersion, ImageVersion
from ..services.gemini_service import generate_text
from ..services.image_pipeline import generate_draft_image
from ..services.watermark_service import create_preview_image
from ..services.storage import upload_image as upload_image_bytes
from ..services.storage import BASE_UPLOAD_DIR, get_server_base_url
from ..services.pdf_service import PdfPage, render_book_pdf
from ..services.tasks import create_task, update_task_progress
from ..core.deps import get_current_user

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/books", tags=["book_editing"])

# Константы ограничений
MAX_TEXT_VARIANTS = 5  # Максимум 5 редактирований + 1 оригинал = 6 вариантов (0-5)
MAX_IMAGE_VARIANTS = 3  # Максимум 3 редактирования + 1 оригинал = 4 варианта (0-3)


# ============================================
# PYDANTIC МОДЕЛИ (синхронизировано с Flutter)
# ============================================

class GenerateTextVariantRequest(BaseModel):
    """Запрос на генерацию нового варианта текста"""
    instruction: str
    current_text: Optional[str] = None  # Опционально, если не указан - берется из сцены


class CustomTextVariantRequest(BaseModel):
    """Запрос на сохранение пользовательского текста"""
    text: str


class GenerateImageVariantRequest(BaseModel):
    """Запрос на генерацию нового варианта изображения"""
    instruction: str
    base_image_url: Optional[str] = None  # Опционально, для img2img


class TextVariantResponse(BaseModel):
    """Ответ с вариантом текста (синхронизировано с Flutter TextVariant)"""
    id: str  # Уникальный ID варианта
    text: str
    variant_number: int  # 0 = оригинал, 1-5 = редактирования
    created_at: str
    instruction: Optional[str] = None
    is_selected: bool
    is_original: bool


class ImageVariantResponse(BaseModel):
    """Ответ с вариантом изображения (синхронизировано с Flutter ImageVariant)"""
    id: str  # Уникальный ID варианта
    image_url: str
    variant_number: int  # 0 = оригинал, 1-3 = редактирования
    created_at: str
    instruction: Optional[str] = None
    is_selected: bool
    is_original: bool


class SceneVariantsResponse(BaseModel):
    """Ответ со всеми вариантами сцены (синхронизировано с Flutter SceneVariants)"""
    scene_id: str  # ID сцены как строка
    text_variants: List[TextVariantResponse]
    image_variants: List[ImageVariantResponse]
    limits: dict  # Информация о лимитах


class SelectVariantsRequest(BaseModel):
    """Запрос на выбор финальных вариантов"""
    selections: List[dict]  # [{"scene_id": "123", "selected_text_variant_id": "tv1", "selected_image_variant_id": "iv1"}]


class LimitsResponse(BaseModel):
    """Ответ с информацией о лимитах редактирования"""
    scene_id: str
    text_edits_used: int
    text_edits_remaining: int
    text_edits_max: int
    image_edits_used: int
    image_edits_remaining: int
    image_edits_max: int


# ============================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================

def _check_book_access(book_id: UUID, user_id: str, db: Session) -> Book:
    """Проверяет доступ к книге и возвращает её"""
    book = db.query(Book).filter(Book.id == book_id).first()
    if not book:
        raise HTTPException(status_code=404, detail="Книга не найдена")
    if str(book.user_id) != str(user_id):
        raise HTTPException(status_code=403, detail="Доступ запрещен")
    return book


def _get_scene_by_id(book_id: UUID, scene_id: int, db: Session) -> Scene:
    """Получает сцену по ID"""
    scene = db.query(Scene).filter(
        and_(Scene.book_id == book_id, Scene.id == scene_id)
    ).first()
    if not scene:
        raise HTTPException(status_code=404, detail=f"Сцена с ID {scene_id} не найдена")
    return scene


def _get_image_by_scene_id(book_id: UUID, scene_id: int, db: Session) -> Optional[Image]:
    """Получает изображение по ID сцены"""
    scene = _get_scene_by_id(book_id, scene_id, db)
    image = db.query(Image).filter(
        and_(Image.book_id == book_id, Image.scene_order == scene.order)
    ).first()
    return image


def _get_text_variant_id(scene_id: int, variant_number: int) -> str:
    """Генерирует ID варианта текста"""
    return f"scene{scene_id}_text_{variant_number}"


def _get_image_variant_id(scene_id: int, variant_number: int) -> str:
    """Генерирует ID варианта изображения"""
    return f"scene{scene_id}_image_{variant_number}"


def _get_next_text_variant_number(book_id: UUID, scene_id: int, db: Session) -> int:
    """Получает следующий номер варианта текста (1-5, где 0 = оригинал)"""
    max_variant = db.query(func.max(TextVersion.version_number)).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene_id
        )
    ).scalar()
    # Если нет вариантов (None) или только оригинал (0), возвращаем 1
    # Если есть варианты, возвращаем следующий (но не больше 5)
    if max_variant is None:
        return 1
    next_variant = max_variant + 1
    return min(next_variant, MAX_TEXT_VARIANTS)


def _get_next_image_variant_number(book_id: UUID, scene_id: int, db: Session) -> int:
    """Получает следующий номер варианта изображения (1-3, где 0 = оригинал)"""
    max_variant = db.query(func.max(ImageVersion.version_number)).filter(
        and_(
            ImageVersion.book_id == book_id,
            ImageVersion.scene_id == scene_id
        )
    ).scalar()
    # Если нет вариантов (None) или только оригинал (0), возвращаем 1
    if max_variant is None:
        return 1
    next_variant = max_variant + 1
    return min(next_variant, MAX_IMAGE_VARIANTS)


def _ensure_original_text_variant(book_id: UUID, scene: Scene, db: Session) -> TextVersion:
    """Создает оригинальный вариант текста (variant_number=0), если его нет"""
    original = db.query(TextVersion).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene.id,
            TextVersion.version_number == 0
        )
    ).first()
    
    if not original:
        original = TextVersion(
            scene_id=scene.id,
            book_id=book_id,
            scene_order=scene.order,
            version_number=0,  # 0 = оригинал
            text=scene.text or "",
            is_original=True,
            is_selected=True  # По умолчанию оригинал выбран
        )
        db.add(original)
        db.commit()
        db.refresh(original)
    
    return original


def _ensure_original_image_variant(book_id: UUID, scene: Scene, image: Image, db: Session) -> Optional[ImageVersion]:
    """Создает оригинальный вариант изображения (variant_number=0), если его нет"""
    if not image:
        return None
    
    original = db.query(ImageVersion).filter(
        and_(
            ImageVersion.book_id == book_id,
            ImageVersion.scene_id == scene.id,
            ImageVersion.version_number == 0
        )
    ).first()
    
    if not original:
        original_url = image.final_url or image.draft_url
        if not original_url:
            return None
        
        original = ImageVersion(
            image_id=image.id,
            book_id=book_id,
            scene_id=scene.id,
            scene_order=scene.order,
            version_number=0,  # 0 = оригинал
            image_url=original_url,
            is_original=True,
            is_selected=True  # По умолчанию оригинал выбран
        )
        db.add(original)
        db.commit()
        db.refresh(original)
    
    return original


# ============================================
# ГЕНЕРАЦИЯ ВАРИАНТА ТЕКСТА
# ============================================

@router.post("/{book_id}/scenes/{scene_id}/text/generate", response_model=TextVariantResponse)
async def generate_text_variant(
    book_id: UUID,
    scene_id: int,
    request: GenerateTextVariantRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерация нового варианта текста через AI.
    
    Создает вариант с variant_number 1-5 (0 зарезервирован для оригинала).
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    book = _check_book_access(book_id, user_id, db)
    
    # Получаем сцену
    scene = _get_scene_by_id(book_id, scene_id, db)
    
    # Создаем оригинальный вариант, если его нет
    _ensure_original_text_variant(book_id, scene, db)
    
    # Проверяем лимит
    current_edits = db.query(func.count(TextVersion.id)).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene_id,
            TextVersion.version_number > 0  # Исключаем оригинал (0)
        )
    ).scalar()
    
    if current_edits >= MAX_TEXT_VARIANTS:
        raise HTTPException(
            status_code=400,
            detail=f"Достигнут лимит редактирования текста ({MAX_TEXT_VARIANTS}). Выберите один из существующих вариантов."
        )
    
    # Получаем текущий текст
    current_text = request.current_text or scene.text or ""
    
    # Генерируем новый текст через AI
    try:
        prompt = f"""Перепиши следующий текст детской книги согласно инструкциям.

Текущий текст сцены:
{current_text}

Инструкции по редактированию:
{request.instruction}

Требования:
1. Следуй инструкциям пользователя
2. Сохрани общий стиль и тон
3. Сделай текст естественным и плавным
4. Верни ТОЛЬКО новый текст сцены, без дополнительных объяснений"""
        
        new_text = await generate_text(prompt, json_mode=False)
        new_text = new_text.strip()
        
        if not new_text or len(new_text) < 10:
            raise ValueError("AI вернул пустой или слишком короткий текст")
        
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации текста: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации нового текста: {str(e)}"
        )
    
    # Создаем новый вариант
    next_variant = _get_next_text_variant_number(book_id, scene_id, db)
    text_version = TextVersion(
        scene_id=scene.id,
        book_id=book_id,
        scene_order=scene.order,
        version_number=next_variant,
        text=new_text,
        edit_instruction=request.instruction,
        is_original=False,
        is_selected=False
    )
    
    db.add(text_version)
    db.commit()
    db.refresh(text_version)
    
    logger.info(f"✅ Создан вариант текста {next_variant} для сцены {scene_id} книги {book_id}")
    
    return TextVariantResponse(
        id=_get_text_variant_id(scene_id, next_variant),
        text=new_text,
        variant_number=next_variant,
        created_at=text_version.created_at.isoformat() if text_version.created_at else "",
        instruction=request.instruction,
        is_selected=False,
        is_original=False
    )


# ============================================
# СОХРАНЕНИЕ ПОЛЬЗОВАТЕЛЬСКОГО ТЕКСТА
# ============================================

@router.post("/{book_id}/scenes/{scene_id}/text/custom", response_model=TextVariantResponse)
def save_custom_text_variant(
    book_id: UUID,
    scene_id: int,
    request: CustomTextVariantRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Сохранение пользовательского текста как нового варианта.
    
    Создает вариант с variant_number 1-5.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    book = _check_book_access(book_id, user_id, db)
    
    # Получаем сцену
    scene = _get_scene_by_id(book_id, scene_id, db)
    
    # Создаем оригинальный вариант, если его нет
    _ensure_original_text_variant(book_id, scene, db)
    
    # Проверяем лимит
    current_edits = db.query(func.count(TextVersion.id)).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene_id,
            TextVersion.version_number > 0
        )
    ).scalar()
    
    if current_edits >= MAX_TEXT_VARIANTS:
        raise HTTPException(
            status_code=400,
            detail=f"Достигнут лимит редактирования текста ({MAX_TEXT_VARIANTS}). Выберите один из существующих вариантов."
        )
    
    # Создаем новый вариант
    next_variant = _get_next_text_variant_number(book_id, scene_id, db)
    text_version = TextVersion(
        scene_id=scene.id,
        book_id=book_id,
        scene_order=scene.order,
        version_number=next_variant,
        text=request.text,
        edit_instruction="Пользовательский текст",
        is_original=False,
        is_selected=False
    )
    
    db.add(text_version)
    db.commit()
    db.refresh(text_version)
    
    logger.info(f"✅ Сохранен пользовательский текст (вариант {next_variant}) для сцены {scene_id}")
    
    return TextVariantResponse(
        id=_get_text_variant_id(scene_id, next_variant),
        text=request.text,
        variant_number=next_variant,
        created_at=text_version.created_at.isoformat() if text_version.created_at else "",
        instruction="Пользовательский текст",
        is_selected=False,
        is_original=False
    )


# ============================================
# ГЕНЕРАЦИЯ ВАРИАНТА ИЗОБРАЖЕНИЯ
# ============================================

@router.post("/{book_id}/scenes/{scene_id}/image/generate", response_model=ImageVariantResponse)
async def generate_image_variant(
    book_id: UUID,
    scene_id: int,
    request: GenerateImageVariantRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Генерация нового варианта изображения через AI.
    
    Создает вариант с variant_number 1-3 (0 зарезервирован для оригинала).
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    book = _check_book_access(book_id, user_id, db)
    
    # Получаем сцену и изображение
    scene = _get_scene_by_id(book_id, scene_id, db)
    image = _get_image_by_scene_id(book_id, scene_id, db)
    
    if not image:
        raise HTTPException(status_code=404, detail="Изображение для сцены не найдено")
    
    # Создаем оригинальный вариант, если его нет
    _ensure_original_image_variant(book_id, scene, image, db)
    
    # Проверяем лимит
    current_edits = db.query(func.count(ImageVersion.id)).filter(
        and_(
            ImageVersion.book_id == book_id,
            ImageVersion.scene_id == scene_id,
            ImageVersion.version_number > 0  # Исключаем оригинал (0)
        )
    ).scalar()
    
    if current_edits >= MAX_IMAGE_VARIANTS:
        raise HTTPException(
            status_code=400,
            detail=f"Достигнут лимит редактирования изображения ({MAX_IMAGE_VARIANTS}). Выберите одно из существующих изображений."
        )
    
    # Получаем базовый промпт
    base_prompt = scene.image_prompt or ""
    
    # Генерируем новый промпт с учетом инструкций
    try:
        prompt = f"""{base_prompt}

Инструкции по редактированию: {request.instruction}

Создай новое изображение на основе оригинального, но с учетом инструкций по редактированию."""
        
        # Генерируем новое изображение
        new_image_url = await generate_draft_image(prompt, style=book.genre or "storybook")
        
    except Exception as e:
        logger.error(f"❌ Ошибка при генерации изображения: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail=f"Ошибка при генерации нового изображения: {str(e)}"
        )
    
    # Создаем новый вариант
    next_variant = _get_next_image_variant_number(book_id, scene_id, db)
    image_version = ImageVersion(
        image_id=image.id,
        book_id=book_id,
        scene_id=scene.id,
        scene_order=scene.order,
        version_number=next_variant,
        image_url=new_image_url,
        edit_instruction=request.instruction,
        is_original=False,
        is_selected=False
    )
    
    db.add(image_version)
    db.commit()
    db.refresh(image_version)
    
    logger.info(f"✅ Создан вариант изображения {next_variant} для сцены {scene_id} книги {book_id}")
    
    return ImageVariantResponse(
        id=_get_image_variant_id(scene_id, next_variant),
        image_url=new_image_url,
        variant_number=next_variant,
        created_at=image_version.created_at.isoformat() if image_version.created_at else "",
        instruction=request.instruction,
        is_selected=False,
        is_original=False
    )


# ============================================
# ПОЛУЧЕНИЕ ВСЕХ ВАРИАНТОВ СЦЕНЫ
# ============================================

@router.get("/{book_id}/scenes/{scene_id}/variants", response_model=SceneVariantsResponse)
def get_scene_variants(
    book_id: UUID,
    scene_id: int,
    preview: bool = Query(False, description="Если True, возвращает preview версии изображений с водяными знаками"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Получить все варианты текста и изображений для сцены.
    
    Синхронизировано с Flutter SceneVariants.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    _check_book_access(book_id, user_id, db)
    
    # Получаем сцену
    scene = _get_scene_by_id(book_id, scene_id, db)
    
    # Получаем варианты текста
    text_versions = db.query(TextVersion).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene_id
        )
    ).order_by(TextVersion.version_number).all()
    
    # Если вариантов нет, создаем оригинальный
    if not text_versions:
        original_text = _ensure_original_text_variant(book_id, scene, db)
        text_versions = [original_text]
    
    # Получаем варианты изображений
    image = _get_image_by_scene_id(book_id, scene_id, db)
    image_versions = []
    if image:
        image_versions = db.query(ImageVersion).filter(
            and_(
                ImageVersion.book_id == book_id,
                ImageVersion.scene_id == scene_id
            )
        ).order_by(ImageVersion.version_number).all()
        
        # Если вариантов нет, создаем оригинальный
        if not image_versions:
            original_image = _ensure_original_image_variant(book_id, scene, image, db)
            if original_image:
                image_versions = [original_image]
    
    # Подсчитываем лимиты
    text_edits_used = len([tv for tv in text_versions if tv.version_number > 0])
    image_edits_used = len([iv for iv in image_versions if iv.version_number > 0])
    
    # Обрабатываем изображения для preview
    image_variants_list = []
    for iv in image_versions:
        image_url = iv.image_url
        
        if preview:
            try:
                response = requests.get(image_url, timeout=10)
                if response.status_code == 200:
                    preview_bytes = create_preview_image(response.content, add_watermark=True)
                    preview_path = f"previews/{uuid_module.uuid4()}.jpg"
                    preview_url = upload_image_bytes(preview_bytes, preview_path, content_type="image/jpeg")
                    image_url = preview_url
            except Exception as e:
                logger.warning(f"⚠️ Не удалось создать preview для {image_url}: {str(e)}")
        
        image_variants_list.append(
            ImageVariantResponse(
                id=_get_image_variant_id(scene_id, iv.version_number),
                image_url=image_url,
                variant_number=iv.version_number,
                created_at=iv.created_at.isoformat() if iv.created_at else "",
                instruction=iv.edit_instruction,
                is_selected=iv.is_selected,
                is_original=iv.is_original
            )
        )
    
    return SceneVariantsResponse(
        scene_id=str(scene_id),
        text_variants=[
            TextVariantResponse(
                id=_get_text_variant_id(scene_id, tv.version_number),
                text=tv.text,
                variant_number=tv.version_number,
                created_at=tv.created_at.isoformat() if tv.created_at else "",
                instruction=tv.edit_instruction,
                is_selected=tv.is_selected,
                is_original=tv.is_original
            )
            for tv in text_versions
        ],
        image_variants=image_variants_list,
        limits={
            "max_text_variants": MAX_TEXT_VARIANTS,
            "remaining_text_edits": MAX_TEXT_VARIANTS - text_edits_used,
            "max_image_variants": MAX_IMAGE_VARIANTS,
            "remaining_image_edits": MAX_IMAGE_VARIANTS - image_edits_used
        }
    )


# ============================================
# ПРОВЕРКА ЛИМИТОВ
# ============================================

@router.get("/{book_id}/scenes/{scene_id}/limits", response_model=LimitsResponse)
def get_scene_limits(
    book_id: UUID,
    scene_id: int,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """Получить информацию о лимитах редактирования для сцены"""
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    _check_book_access(book_id, user_id, db)
    
    # Получаем сцену
    scene = _get_scene_by_id(book_id, scene_id, db)
    
    # Подсчитываем использованные редактирования
    text_edits_used = db.query(func.count(TextVersion.id)).filter(
        and_(
            TextVersion.book_id == book_id,
            TextVersion.scene_id == scene_id,
            TextVersion.version_number > 0
        )
    ).scalar() or 0
    
    image_edits_used = db.query(func.count(ImageVersion.id)).filter(
        and_(
            ImageVersion.book_id == book_id,
            ImageVersion.scene_id == scene_id,
            ImageVersion.version_number > 0
        )
    ).scalar() or 0
    
    return LimitsResponse(
        scene_id=str(scene_id),
        text_edits_used=text_edits_used,
        text_edits_remaining=MAX_TEXT_VARIANTS - text_edits_used,
        text_edits_max=MAX_TEXT_VARIANTS,
        image_edits_used=image_edits_used,
        image_edits_remaining=MAX_IMAGE_VARIANTS - image_edits_used,
        image_edits_max=MAX_IMAGE_VARIANTS
    )


# ============================================
# ВЫБОР ФИНАЛЬНЫХ ВАРИАНТОВ
# ============================================

@router.post("/{book_id}/finalize/select")
def select_final_variants(
    book_id: UUID,
    request: SelectVariantsRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Выбрать финальные варианты для всех сцен.
    
    Синхронизировано с Flutter: принимает массив selections.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    book = _check_book_access(book_id, user_id, db)
    
    # Обрабатываем каждую сцену
    for selection in request.selections:
        scene_id = int(selection["scene_id"])
        scene = _get_scene_by_id(book_id, scene_id, db)
        
        # Выбираем вариант текста
        if "selected_text_variant_id" in selection and selection["selected_text_variant_id"]:
            variant_id = selection["selected_text_variant_id"]
            # Извлекаем variant_number из ID (формат: "scene123_text_1")
            try:
                variant_number = int(variant_id.split("_")[-1])
            except:
                raise HTTPException(status_code=400, detail=f"Неверный формат variant_id: {variant_id}")
            
            # Снимаем выбор со всех вариантов
            db.query(TextVersion).filter(
                and_(
                    TextVersion.book_id == book_id,
                    TextVersion.scene_id == scene_id
                )
            ).update({"is_selected": False})
            
            # Выбираем нужный вариант
            text_version = db.query(TextVersion).filter(
                and_(
                    TextVersion.book_id == book_id,
                    TextVersion.scene_id == scene_id,
                    TextVersion.version_number == variant_number
                )
            ).first()
            
            if text_version:
                text_version.is_selected = True
                # Обновляем текст в сцене
                scene.text = text_version.text
        
        # Выбираем вариант изображения
        if "selected_image_variant_id" in selection and selection["selected_image_variant_id"]:
            variant_id = selection["selected_image_variant_id"]
            try:
                variant_number = int(variant_id.split("_")[-1])
            except:
                raise HTTPException(status_code=400, detail=f"Неверный формат variant_id: {variant_id}")
            
            # Снимаем выбор со всех вариантов
            db.query(ImageVersion).filter(
                and_(
                    ImageVersion.book_id == book_id,
                    ImageVersion.scene_id == scene_id
                )
            ).update({"is_selected": False})
            
            # Выбираем нужный вариант
            image_version = db.query(ImageVersion).filter(
                and_(
                    ImageVersion.book_id == book_id,
                    ImageVersion.scene_id == scene_id,
                    ImageVersion.version_number == variant_number
                )
            ).first()
            
            if image_version:
                image_version.is_selected = True
                # Обновляем изображение в таблице Image
                image = _get_image_by_scene_id(book_id, scene_id, db)
                if image:
                    image.final_url = image_version.image_url
    
    db.commit()
    
    logger.info(f"✅ Выбраны финальные варианты для книги {book_id}")
    
    return {
        "status": "ok",
        "book_id": str(book_id),
        "ready_for_finalization": True
    }


# ============================================
# ФИНАЛЬНЫЙ РЕНДЕРИНГ
# ============================================

@router.post("/{book_id}/finalize/render")
def finalize_render(
    book_id: UUID,
    db: Session = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """
    Финальный рендеринг книги с выбранными вариантами.
    
    Проверяет, что для всех сцен выбраны варианты, затем создает финальную версию.
    """
    user_id = current_user.get("sub") or current_user.get("id")
    if not user_id:
        raise HTTPException(status_code=401, detail="Не авторизован")
    
    # Проверяем доступ к книге
    book = _check_book_access(book_id, user_id, db)
    
    # Получаем все сцены
    scenes = db.query(Scene).filter(Scene.book_id == book_id).order_by(Scene.order).all()
    
    if not scenes:
        raise HTTPException(status_code=404, detail="Сцены не найдены")
    
    # Проверяем, что для всех сцен выбраны варианты
    for scene in scenes:
        # Проверяем текст
        selected_text = db.query(TextVersion).filter(
            and_(
                TextVersion.book_id == book_id,
                TextVersion.scene_id == scene.id,
                TextVersion.is_selected == True
            )
        ).first()
        
        if not selected_text:
            # Если нет выбранной версии, используем оригинальный текст
            if not scene.text:
                raise HTTPException(
                    status_code=400,
                    detail=f"Для сцены {scene.id} не выбран текст"
                )
        
        # Проверяем изображение
        selected_image = db.query(ImageVersion).filter(
            and_(
                ImageVersion.book_id == book_id,
                ImageVersion.scene_id == scene.id,
                ImageVersion.is_selected == True
            )
        ).first()
        
        if not selected_image:
            # Если нет выбранной версии, проверяем оригинальное изображение
            image = _get_image_by_scene_id(book_id, scene.id, db)
            if not image or not (image.final_url or image.draft_url):
                raise HTTPException(
                    status_code=400,
                    detail=f"Для сцены {scene.id} не выбрано изображение"
                )
    
    async def _render_pdf_task(task_id: Optional[str] = None):
        """
        Асинхронный рендеринг PDF (скачивает выбранные картинки, собирает PDF, сохраняет в /static).
        """
        if task_id:
            update_task_progress(task_id, {
                "stage": "rendering_pdf",
                "current_step": 1,
                "total_steps": 1,
                "message": "Сборка PDF...",
                "pages_rendered": 0,
                "total_pages": len([s for s in scenes if s.order > 0]),  # Исключаем обложку (order=0)
                "book_id": str(book_id)
            })

        # Получаем ребёнка для возраста
        from ..models import Child
        child = db.query(Child).filter(Child.id == book.child_id).first()
        child_age = child.age if child else None
        
        # Собираем страницы (сортируем по order, чтобы обложка order=0 была первой)
        pages: list[PdfPage] = []
        # Сортируем сцены по order, чтобы обложка (order=0) была первой
        sorted_scenes = sorted(scenes, key=lambda s: s.order)
        for idx, scene in enumerate(sorted_scenes, 1):
            image = _get_image_by_scene_id(book_id, scene.id, db)
            image_url = None
            if image:
                image_url = image.final_url or image.draft_url
            pages.append(PdfPage(
                order=scene.order,
                text=scene.text or "",
                image_url=image_url,
                age=child_age
            ))

            if task_id:
                update_task_progress(task_id, {
                    "pages_rendered": idx - 1,
                    "message": f"Подготовка страницы {idx}/{len(sorted_scenes)}..."
                })

        # Путь на диске
        out_path = Path(BASE_UPLOAD_DIR) / "books" / str(book_id) / "final.pdf"

        # Получаем стиль книги
        from ..models import ThemeStyle
        theme_style = db.query(ThemeStyle).filter(ThemeStyle.book_id == book_id).first()
        book_style = theme_style.final_style if theme_style else (book.style or "storybook")

        # Генерация PDF (CPU/IO) — в отдельном потоке
        import asyncio
        await asyncio.to_thread(render_book_pdf, out_path, book.title or "StoryHero", pages, book_style, child_age)

        # Публичный URL
        base = get_server_base_url()
        pdf_url = f"{base}/static/books/{book_id}/final.pdf"

        # Сохраняем в БД
        book.final_pdf_url = pdf_url
        book.status = "finalized"
        db.commit()

        if task_id:
            update_task_progress(task_id, {
                "stage": "pdf_ready",
                "message": "PDF готов ✓",
                "pages_rendered": len(scenes),
                "total_pages": len([s for s in scenes if s.order > 0]),  # Исключаем обложку (order=0)
                "pdf_url": pdf_url
            })

        return {"pdf_url": pdf_url}

    # Создаем задачу рендеринга PDF
    task_id = create_task(
        _render_pdf_task,
        meta={"type": "render_pdf", "user_id": str(user_id), "book_id": str(book_id)}
    )

    logger.info(f"✅ Книга {book_id} отправлена на финальный рендеринг PDF: task_id={task_id}")

    return {
        "task_id": task_id,
        "status": "processing",
        "estimated_time_seconds": 120
    }
