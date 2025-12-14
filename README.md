# 📖 StoryHero

StoryHero — это мобильное приложение для создания персонализированных детских книг с помощью искусственного интеллекта.

Проект состоит из Flutter-клиента и FastAPI-бэкенда, объединённых в единый monorepo.

---

## 🧩 Архитектура проекта

storyhero/
├── frontend/ # Flutter (Android / iOS / Web)
├── backend/ # FastAPI + Background workers
├── shared/
│ ├── api_contracts/ # Контракты API (JSON / OpenAPI)
│ └── schemas/ # Общие схемы данных
├── infra/
│ ├── nginx/ # Nginx конфигурация
│ └── docker-compose.yml
└── README.md

markdown
Копировать код

---

## 📱 Frontend (Flutter)

**Стек:**
- Flutter (stable)
- Riverpod
- GoRouter
- Freezed / JSON Serializable
- Supabase Auth

**Функциональность:**
- Аутентификация пользователя
- Управление профилями детей
- Создание книг
- Отслеживание статуса генерации
- Просмотр готовых книг и сцен

**Запуск локально:**
```bash
cd frontend
flutter pub get
flutter run
🧠 Backend (FastAPI)
Стек:

FastAPI

PostgreSQL

Background tasks / workers

AI-сервисы (LLM, генерация изображений, face swap)

Docker

Основные модули:

Auth (JWT / Supabase)

Children

Books

Scenes

Async workflow генерации книг

Image pipeline

Запуск локально (без Docker):

bash
Копировать код
cd backend
python -m venv venv
source venv/bin/activate  # Linux/Mac
venv\Scripts\activate     # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload
🐳 Docker / Infra
Проект поддерживает запуск через Docker Compose.

Контейнеры:

storyhero-backend

storyhero-postgres

storyhero-nginx

Запуск:

bash
Копировать код
docker compose up -d --build
📄 API Contracts
Контракты API лежат в:

bash
Копировать код
shared/api_contracts/
Используются для:

синхронизации frontend ↔ backend

E2E тестирования

предотвращения type-mismatch ошибок

🔐 Безопасность
❗ В репозиторий НЕ КЛАДУТСЯ:

.env

API-ключи

SSH-ключи

AI-модели

Бэкапы БД

Все чувствительные данные передаются через переменные окружения.

🚀 Статус проекта
✅ Frontend: активная разработка

✅ Backend: production-ready

✅ Docker: используется в продакшене

🔄 CI/CD: в планах

👤 Автор
StoryHero
Разработка и архитектура: Maksim Yugov

📝 Лицензия
Private / Internal (по умолчанию)