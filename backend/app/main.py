import os
import re
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

    # ЗАКОММЕНТИРОВАНО - перешли на Pollinations.ai (не требует API ключа)
    # if not os.getenv("FAL_API_KEY"):
    #     print("⚠ ВНИМАНИЕ: FAL_API_KEY не установлен! Генерация изображений не будет работать")
    # else:
    #     print("✓ FAL_API_KEY установлен")
    print("✓ Используется Pollinations.ai для генерации изображений (API ключ не требуется)")
    
    if not os.getenv("GEMINI_API_KEY"):
        print("⚠ ВНИМАНИЕ: GEMINI_API_KEY не установлен! Генерация текста не будет работать")
    else:
        print("✓ GEMINI_API_KEY установлен")

# Теперь импортируем модули, которые используют переменные окружения
from fastapi import FastAPI, Depends, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import Response
from sqlalchemy.orm import Session
from sqlalchemy import text

from .db import get_db, init_db
from .services.storage import BASE_UPLOAD_DIR
from .services.cleanup_service import cleanup_old_drafts
from .services.subscription_service import check_expired_subscriptions
from .routers import (
    book_editing,
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
    payments,
    orders,
    subscription,
    support,
    test_notifications,
)

app = FastAPI(
    title="StoryHero Backend",
    version="0.1.0",
)

scheduler: AsyncIOScheduler | None = None

# =============================================================================
# CORS настройки для веб-версии и мобильного приложения
# =============================================================================
# Разрешённые origins для CORS
ALLOWED_ORIGINS = [
    # Production домены
    "https://storyhero.ru",
    "https://www.storyhero.ru",
    "https://api.storyhero.ru",
    # Development
    "http://localhost:3000",      # React/Next.js dev server
    "http://localhost:8080",      # Flutter Web dev server
    "http://localhost:5000",      # Другие dev серверы
    "http://127.0.0.1:3000",
    "http://127.0.0.1:8080",
    "http://127.0.0.1:5000",
    # Примечание: localhost с любым портом поддерживается через allow_origin_regex
]

# Настройка CORS для Flutter приложения и веб-версии
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1):\d+",
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition", "X-Request-ID"],
    max_age=600,
)

# =============================================================================
# Security Headers Middleware
# =============================================================================
@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Добавляет заголовки безопасности к ответам."""
    response = await call_next(request)
    
    # HSTS - принудительное использование HTTPS (1 год)
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    
    # Предотвращение MIME-sniffing
    response.headers["X-Content-Type-Options"] = "nosniff"
    
    # Защита от clickjacking (разрешаем только с того же домена)
    response.headers["X-Frame-Options"] = "SAMEORIGIN"
    
    # XSS защита (для старых браузеров)
    response.headers["X-XSS-Protection"] = "1; mode=block"
    
    # Referrer Policy
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    return response


# =============================================================================
# Request Logging Middleware (для отладки CORS)
# =============================================================================
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Логирует запросы с origin для отладки CORS."""
    origin = request.headers.get("origin", "no-origin")
    method = request.method
    path = request.url.path
    
    # Логируем только запросы с origin (браузерные запросы)
    if origin != "no-origin":
        logger.info(f"🌐 Web request: {method} {path} from origin: {origin}")
    
    try:
        response = await call_next(request)
        
        # Логируем ошибки CORS (когда origin не разрешён)
        import re

        if origin != "no-origin":
            allowed = (
                origin in ALLOWED_ORIGINS
                or re.match(r"http://localhost:\d+", origin)
                or re.match(r"http://127\.0\.0\.1:\d+", origin)
            )
            if not allowed:
                logger.warning(
                    f"⚠️ CORS: Запрос с неразрешённого origin: {origin} → {method} {path}"
                )
        
        # Логируем статус ответа для важных эндпоинтов
        if path.startswith("/api/v1/children") and method in ["PUT", "POST"]:
            logger.info(f"📝 {method} {path} → {response.status_code}")
        
        return response
    except Exception as e:
        logger.error(f"❌ Ошибка при обработке запроса {method} {path}: {str(e)}", exc_info=True)
        raise

# Подключение статической раздачи файлов
# Файлы доступны по /static/children/<child_id>/<filename> или /static/general/<filename>
try:
    # Создаём базовую директорию, если её нет
    os.makedirs(BASE_UPLOAD_DIR, exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "children"), exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "general"), exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "faces"), exist_ok=True)  # Для face profile reference изображений
    
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
app.include_router(book_editing.router)  # Редактирование книг (версии текста и изображений)
app.include_router(final_images.router)
app.include_router(style.router)
app.include_router(auth_info.router)
# Важно: children.router регистрируем ПЕРЕД upload.router
# чтобы /children/{child_id}/photos имел приоритет над /children/photos
app.include_router(children.router)
app.include_router(upload.router)
# Платежи и заказы
app.include_router(payments.router)
app.include_router(orders.router)
app.include_router(subscription.router)
app.include_router(support.router)  # Сообщения поддержки
app.include_router(test_notifications.router)  # Тестовые эндпоинты

# -----------------------------------------------------------------------------
# BACKWARD/FRONTEND COMPAT: /api/v1 prefix
# -----------------------------------------------------------------------------
# Flutter в проде использует baseUrl вида https://storyhero.ru/api/v1
# Nginx проксирует запросы "как есть" (без strip), поэтому FastAPI должен
# поддерживать маршруты и с префиксом /api/v1/*.
API_V1_PREFIX = "/api/v1"

app.include_router(auth.router, prefix=API_V1_PREFIX)
app.include_router(profile.router, prefix=API_V1_PREFIX)
app.include_router(plot.router, prefix=API_V1_PREFIX)
app.include_router(text_router.router, prefix=API_V1_PREFIX)
app.include_router(image_prompts.router, prefix=API_V1_PREFIX)
app.include_router(images.router, prefix=API_V1_PREFIX)
app.include_router(books.router, prefix=API_V1_PREFIX)
app.include_router(books_workflow.router, prefix=API_V1_PREFIX)
app.include_router(book_editing.router, prefix=API_V1_PREFIX)
app.include_router(final_images.router, prefix=API_V1_PREFIX)
app.include_router(style.router, prefix=API_V1_PREFIX)
app.include_router(auth_info.router, prefix=API_V1_PREFIX)
# Важно: children.router перед upload.router, чтобы /children/{child_id}/photos имел приоритет
app.include_router(children.router, prefix=API_V1_PREFIX)
app.include_router(upload.router, prefix=API_V1_PREFIX)
# Платежи и заказы
app.include_router(payments.router, prefix=API_V1_PREFIX)
app.include_router(orders.router, prefix=API_V1_PREFIX)
app.include_router(subscription.router, prefix=API_V1_PREFIX)
app.include_router(support.router, prefix=API_V1_PREFIX)  # Сообщения поддержки
app.include_router(test_notifications.router, prefix=API_V1_PREFIX)  # Тестовые эндпоинты

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
        os.makedirs(os.path.join(BASE_UPLOAD_DIR, "faces"), exist_ok=True)  # Для face profile reference изображений
        logger.info(f"✓ Директории для локального хранения файлов готовы: {BASE_UPLOAD_DIR}")
    except Exception as e:
        logger.error(f"✗ Ошибка при создании директорий для хранения файлов: {str(e)}")
        logger.error("   Убедитесь, что у приложения есть права на запись в /var/www/storyhero/uploads")
    
    # Запуск планировщика очистки черновиков
    try:
        scheduler = AsyncIOScheduler()
        # Каждый день в 04:00 по серверному времени
        scheduler.add_job(cleanup_old_drafts, "cron", hour=4, minute=0)
        # Каждый день в 04:10 деактивируем истёкшие подписки
        scheduler.add_job(check_expired_subscriptions, "cron", hour=4, minute=10)
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


# =============================================================================
# CORS Test Endpoint
# =============================================================================
@app.get("/api/v1/cors-test")
@app.get("/cors-test")
def cors_test(request: Request):
    origin = request.headers.get("origin", "no-origin")
    return {
        "status": "ok",
        "message": "CORS is configured correctly",
        "request_origin": origin,
        "origin_allowed": (
            origin == "no-origin"
            or origin in ALLOWED_ORIGINS
            or re.match(r"http://localhost:\d+", origin)
        ),
        "allowed_origins": ALLOWED_ORIGINS,
        "cors_info": {
            "credentials": True,
            "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
            "max_age": 600
        }
    }

