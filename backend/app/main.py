import os
import logging
from pathlib import Path
from apscheduler.schedulers.asyncio import AsyncIOScheduler

# Настройка логирования - ДЕТАЛЬНОЕ для отладки
logging.basicConfig(
    level=logging.DEBUG,  # Изменено на DEBUG для детального логирования
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

# Устанавливаем уровень логирования для всех модулей
logging.getLogger("app").setLevel(logging.DEBUG)
logging.getLogger("app.routers").setLevel(logging.DEBUG)
logging.getLogger("app.services").setLevel(logging.DEBUG)
logger = logging.getLogger(__name__)

# ВАЖНО: Загружаем .env файл ПЕРЕД всеми импортами, которые используют переменные окружения
def load_env_file(env_path):
    """Простая загрузка .env файла без зависимостей"""
    try:
        if Path(env_path).exists():
            loaded_count = 0
            with open(env_path, 'r') as f:
                for line in f:
                    line = line.strip()
                    # Пропускаем комментарии и пустые строки
                    if line and not line.startswith('#'):
                        if '=' in line:
                            key, value = line.split('=', 1)
                            key = key.strip()
                            value = value.strip().strip('"').strip("'")
                            # Устанавливаем переменную (перезаписываем существующие)
                            if key:
                                os.environ[key] = value
                                loaded_count += 1
            if loaded_count > 0:
                print(f"✓ Загружено {loaded_count} переменных из {env_path}")
            return True
    except Exception as e:
        print(f"⚠ Ошибка при загрузке .env: {e}")
    return False

# Пробуем загрузить .env из разных мест (в порядке приоритета)
env_loaded = False
for env_path in ["/app/.env", "/app/backend/.env", ".env"]:
    if load_env_file(env_path):
        env_loaded = True
        break

if not env_loaded:
    print("⚠ .env файл не найден, используем переменные окружения системы")
else:
    # Проверяем наличие критических переменных
    if not os.getenv("SECRET_KEY"):
        print("⚠ ВНИМАНИЕ: SECRET_KEY не установлен! Используется значение по умолчанию (небезопасно для production)")
    else:
        print("✓ SECRET_KEY установлен")

# Теперь импортируем модули, которые используют переменные окружения
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from sqlalchemy import text

from .db import get_db, init_db
from .services.local_file_service import BASE_UPLOAD_DIR
from .services.cleanup_service import cleanup_old_drafts
from .routers import (
    profile,
    plot,
    text as text_router,
    image_prompts,
    images,
    books,
    books_workflow,
    final_images,
    style,
    auth_info,
    children,
    upload,
    auth,
)

app = FastAPI(
    title="StoryHero Backend",
    version="0.1.0",
)

scheduler: AsyncIOScheduler | None = None

# Настройка CORS для Flutter приложения
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # В production указать конкретные домены
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Подключение статической раздачи файлов
# Файлы доступны по /static/children/<child_id>/<filename> или /static/general/<filename>
try:
    # Создаём базовую директорию, если её нет
    os.makedirs(BASE_UPLOAD_DIR, exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "children"), exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "general"), exist_ok=True)
    
    app.mount("/static", StaticFiles(directory=BASE_UPLOAD_DIR), name="static")
    logger.info(f"✓ Статическая раздача файлов настроена: {BASE_UPLOAD_DIR}")
except Exception as e:
    logger.error(f"✗ Ошибка при настройке статической раздачи файлов: {str(e)}")
    logger.error("   Убедитесь, что директория /var/www/storyhero/uploads существует и доступна для записи")

# Подключаем роутеры
app.include_router(auth.router)  # Аутентификация (регистрация, логин)
app.include_router(profile.router)
app.include_router(plot.router)
app.include_router(text_router.router)
app.include_router(image_prompts.router)
app.include_router(images.router)
app.include_router(books.router)
app.include_router(books_workflow.router)  # Workflow endpoints для книг
app.include_router(final_images.router)
app.include_router(style.router)
app.include_router(auth_info.router)
# Важно: children.router регистрируем ПЕРЕД upload.router
# чтобы /children/{child_id}/photos имел приоритет над /children/photos
app.include_router(children.router)
app.include_router(upload.router)

# Инициализируем БД при запуске
@app.on_event("startup")
async def startup_event():
    global scheduler
    # Инициализация PostgreSQL БД (SQLAlchemy)
    # Все модели автоматически импортируются в init_db()
    init_db()
    
    # Инициализация завершена - используем локальную аутентификацию
    logger.info("✓ Локальная аутентификация готова")
    
    # Проверка директории для локального хранения файлов
    logger.info("Проверка директории для локального хранения файлов...")
    try:
        # Создаём директории, если их нет
        os.makedirs(BASE_UPLOAD_DIR, exist_ok=True)
        os.makedirs(os.path.join(BASE_UPLOAD_DIR, "children"), exist_ok=True)
        os.makedirs(os.path.join(BASE_UPLOAD_DIR, "general"), exist_ok=True)
        logger.info(f"✓ Директории для локального хранения файлов готовы: {BASE_UPLOAD_DIR}")
    except Exception as e:
        logger.error(f"✗ Ошибка при создании директорий для хранения файлов: {str(e)}")
        logger.error("   Убедитесь, что у приложения есть права на запись в /var/www/storyhero/uploads")
    
    # Запуск планировщика очистки черновиков
    try:
        scheduler = AsyncIOScheduler()
        # Каждый день в 04:00 по серверному времени
        scheduler.add_job(cleanup_old_drafts, "cron", hour=4, minute=0)
        scheduler.start()
        logger.info("✓ Планировщик очистки черновиков запущен (ежедневно в 04:00)")
    except Exception as e:
        logger.error(f"✗ Не удалось запустить планировщик очистки: {e}", exc_info=True)
    
    # Выводим все зарегистрированные маршруты для отладки
    print("\n" + "="*70)
    print("ЗАРЕГИСТРИРОВАННЫЕ МАРШРУТЫ FASTAPI:")
    print("="*70)
    
    # Проверяем подключение роутеров
    print("\nПроверка подключения роутеров:")
    try:
        from .routers import children, books
        print(f"✓ children.router: prefix={children.router.prefix}, tags={children.router.tags}")
        print(f"✓ books.router: prefix={books.router.prefix}, tags={books.router.tags}")
    except Exception as e:
        print(f"✗ Ошибка при импорте роутеров: {e}")
    
    # Собираем все маршруты
    routes = []
    all_paths = []
    for route in app.routes:
        if hasattr(route, "path"):
            all_paths.append(route.path)
            if hasattr(route, "methods"):
                methods = ", ".join(sorted(route.methods))
                routes.append(f"{methods:25} {route.path}")
            else:
                routes.append(f"{'':25} {route.path}")
    
    # Сортируем маршруты для удобства
    routes.sort()
    print(f"\nВсего маршрутов: {len(routes)}")
    print("\nСписок всех маршрутов:")
    for route in routes:
        print(f"  {route}")
    
    # Проверяем наличие ключевых маршрутов
    print("\n" + "="*70)
    print("ПРОВЕРКА КЛЮЧЕВЫХ МАРШРУТОВ:")
    print("="*70)
    required_paths = {
        "/children": ["POST", "GET"],
        "/children/{child_id}": ["GET", "DELETE"],
        "/books": ["GET", "POST"],
        "/books/generate_full_book": ["POST"],
        "/books/task_status/{task_id}": ["GET"]
    }
    
    for path_pattern, expected_methods in required_paths.items():
        # Ищем маршруты, которые соответствуют паттерну
        matching_routes = []
        for route in app.routes:
            if hasattr(route, "path"):
                route_path = route.path
                # Простая проверка соответствия
                if route_path == path_pattern or route_path.startswith(path_pattern.split("{")[0]):
                    methods = getattr(route, "methods", set())
                    matching_routes.append((route_path, methods))
        
        if matching_routes:
            status = "✓"
            print(f"{status} {path_pattern}")
            for route_path, methods in matching_routes:
                method_str = ", ".join(sorted(methods)) if methods else "N/A"
                print(f"    → {method_str:20} {route_path}")
        else:
            status = "✗"
            print(f"{status} {path_pattern}: НЕ НАЙДЕН")
    
    print("="*70 + "\n")


@app.get("/")
def root():
    return {"status": "ok", "message": "StoryHero backend running!"}


@app.get("/health/db")
def health_db(db: Session = Depends(get_db)):
    try:
        result = db.execute(text("SELECT 1")).scalar()
        return {"db": "ok", "result": result}
    except Exception as e:
        return {"db": "error", "detail": str(e)}
