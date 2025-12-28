"""
Интеграционный smoke-test полного цикла:
1) создаём тестового пользователя и ребёнка
2) запускаем /books/generate_draft (10 страниц)
3) запускаем финальный рендер PDF через /books/{book_id}/finalize/render
4) ждём завершения задачи и проверяем наличие final.pdf на диске

Важно:
- Ключи/секреты НЕ печатаем.
- Берём env из /opt/storyhero/storyhero/.env (как у вас настроено), если переменные не заданы.
"""

from __future__ import annotations

import asyncio
import os
import sys
import time
import uuid
from pathlib import Path


ENV_PATH = "/opt/storyhero/storyhero/.env"

# Чтобы `import app...` работал при запуске файла напрямую:
# backend/app/scripts/full_cycle_smoketest.py -> добавляем backend/ в sys.path
_PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(_PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(_PROJECT_ROOT))


def load_env_file(path: str) -> None:
    if not os.path.exists(path):
        return
    with open(path, "r", encoding="utf-8", errors="ignore") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            k = k.strip()
            v = v.strip().strip('"').strip("'")
            if k and k not in os.environ:
                os.environ[k] = v


async def main() -> int:
    # Подтягиваем env (не перетираем уже заданные переменные)
    load_env_file(ENV_PATH)

    # Простейшая валидация наличия ключевых env
    if not os.getenv("GEMINI_API_KEY"):
        print("ERROR: GEMINI_API_KEY не найден в окружении/.env — прогон невозможен")
        return 2
    if not os.getenv("DATABASE_URL"):
        print("ERROR: DATABASE_URL не найден в окружении/.env — прогон невозможен")
        return 3

    # Локальные директории для хранения файлов (как в app.main)
    from app.services.storage import BASE_UPLOAD_DIR

    os.makedirs(BASE_UPLOAD_DIR, exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "children"), exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "general"), exist_ok=True)
    os.makedirs(os.path.join(BASE_UPLOAD_DIR, "books"), exist_ok=True)

    # DB init
    from app.db import init_db, SessionLocal

    init_db()

    # Создаём тестового пользователя
    from app.models.user import User
    from app.models.child import Child

    user_uuid = uuid.uuid4()
    user_email = f"smoketest-{int(time.time())}@example.com"

    db = SessionLocal()
    try:
        u = User(
            id=user_uuid,
            email=user_email,
            hashed_password="smoketest",
            is_active=True,
        )
        db.add(u)
        db.commit()
    except Exception:
        db.rollback()
        # если вдруг уже есть — попробуем загрузить
        u = db.query(User).filter(User.email == user_email).first()
        if not u:
            raise
        user_uuid = u.id

    user_id = str(user_uuid)

    # Создаём ребёнка
    child = Child(
        name="Тест",
        age=7,
        interests=["космос", "динозавры"],
        fears=["темнота"],
        personality="добрый и любознательный",
        moral="быть смелым и помогать друзьям",
        profile_json={},
        user_id=user_id,
        face_url=None,
    )
    db.add(child)
    db.commit()
    db.refresh(child)

    # Запускаем workflow генерации черновика (полный цикл до draft images + pages)
    from app.routers.books_workflow import generate_draft, GenerateDraftRequest

    current_user = {"id": user_id, "sub": user_id, "email": user_email}

    print(f"STEP: generate_draft (child_id={child.id}, pages=10)")
    book_out = await generate_draft(
        data=GenerateDraftRequest(child_id=str(child.id), style="classic", num_pages=10),
        db=db,
        current_user=current_user,
    )
    book_id = str(getattr(book_out, "id", None) or getattr(book_out, "book_id", None) or "")
    if not book_id:
        # pydantic model from schema
        book_id = str(book_out.id)
    print(f"OK: draft generated (book_id={book_id})")

    # Запускаем финальный рендер PDF (через book_editing)
    from uuid import UUID as UUIDType
    from app.routers.book_editing import finalize_render
    from app.services.tasks import get_task_status
    from app.services.storage import BASE_UPLOAD_DIR

    print("STEP: finalize_render (PDF)")
    resp = finalize_render(book_id=UUIDType(book_id), db=db, current_user=current_user)
    task_id = resp.get("task_id")
    if not task_id:
        print(f"ERROR: finalize_render не вернул task_id: {resp}")
        return 4
    print(f"OK: render task started (task_id={task_id})")

    # Ждём завершения задачи
    deadline = time.time() + 15 * 60  # 15 минут
    last_stage = None
    while time.time() < deadline:
        st = get_task_status(task_id) or {}
        status = st.get("status")
        progress = st.get("progress") or {}
        stage = progress.get("stage")
        if stage and stage != last_stage:
            print(f"PROGRESS: stage={stage}")
            last_stage = stage
        if status in ("success", "error"):
            break
        await asyncio.sleep(1.0)

    st = get_task_status(task_id) or {}
    status = st.get("status")
    if status != "success":
        print(f"ERROR: task status={status}, error={st.get('error')}")
        return 5

    result = st.get("result") or {}
    pdf_url = result.get("pdf_url")

    # Проверяем файл на диске
    pdf_path = Path(BASE_UPLOAD_DIR) / "books" / book_id / "final.pdf"
    if not pdf_path.exists():
        print(f"ERROR: PDF файл не найден на диске: {pdf_path}")
        print(f"task_result_pdf_url={pdf_url}")
        return 6

    size = pdf_path.stat().st_size
    if size <= 0:
        print(f"ERROR: PDF файл пустой: {pdf_path}")
        return 7

    print(f"SUCCESS: PDF создан: {pdf_path} ({size} bytes)")
    if pdf_url:
        print(f"pdf_url={pdf_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))


