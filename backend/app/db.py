from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://storyhero:storyhero_pass@127.0.0.1:5432/storyhero_db",  # Локальная БД через host network
)

engine = create_engine(DATABASE_URL, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)

Base = declarative_base()


# ВАЖНО: Импортируем все модели после создания Base,
# чтобы SQLAlchemy мог правильно разрешить все relationship
def import_all_models():
    """Импортирует все модели для правильной регистрации relationship"""
    from .models import Book, Scene, Child, Image, ThemeStyle, User  # noqa: F401


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Создает все таблицы в базе данных"""
    import_all_models()
    Base.metadata.create_all(bind=engine)
