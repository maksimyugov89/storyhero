#  <img width="1024" height="1024" alt="icon" src="https://github.com/user-attachments/assets/bc0704c8-8342-4c96-ac48-06631abec4cc" /> StoryHero

StoryHero — это мобильное приложение для создания персонализированных детских книг с помощью искусственного интеллекта.

Проект состоит из Flutter-клиента и FastAPI-бэкенда, объединённых в единый monorepo.

## Скриншоты 
![Screenshot_2026-02-24-13-23-47-50_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/1557feb7-54cc-4e06-811c-2244eb7e78dd)
![Screenshot_2026-02-24-13-23-56-20_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/990d0a51-cc17-40bd-9ec7-0d586217abd0)
![Screenshot_2026-02-24-13-25-26-41_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/4fb876cf-8404-4f9e-acb4-7d2a94347a66)
![Screenshot_2026-02-24-13-26-10-89_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/4897d670-5412-438c-acc5-04aec43e348d)
![Screenshot_2026-02-24-13-26-10-89_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/8ba99fb5-6478-4b07-bd3a-3859816eda12)
![Screenshot_2026-02-24-13-26-29-76_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/75064a58-9e15-4eb4-afbe-f7fd912e47b2)
![Screenshot_2026-02-24-13-26-34-62_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/78434254-7de0-4ad9-9035-8872748f5b36)
![Screenshot_2026-02-24-13-26-44-18_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/e541aa4d-8a71-449e-92df-6e8a73453c76)
![Screenshot_2026-02-24-13-26-57-70_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/f31a47eb-6df5-445d-956d-02964a796707)
![Screenshot_2026-02-24-13-27-05-94_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/0b5c2ef9-0c6c-4b77-be66-aecef092f532)
![Screenshot_2026-01-22-01-54-36-70_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/91bab22a-1e87-46f6-b4e7-f784ad45948f)
![Screenshot_2026-02-24-13-34-52-80_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/3357dc08-5c4e-4ba9-96b3-51f5cdbb3e5e)
![Screenshot_2026-02-24-13-35-02-23_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/e315cc54-151d-4575-9694-ad72adea4023)
![Screenshot_2026-02-24-13-35-23-86_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/9f7a60f5-06f3-4463-8c10-0ce7dec9023a)
![Screenshot_2026-02-24-13-35-37-04_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/9b30e77a-e956-4fbe-8c37-ee19737e5688)
![Screenshot_2026-02-24-13-40-35-22_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/8d63b028-fa47-4c2b-8418-4c1d6b53db95)
![Screenshot_2026-02-24-13-40-13-08_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/62f35f15-c702-4154-aec7-b6a9c2954e89)
![Screenshot_2026-02-24-13-40-24-60_cd185c28346566a3b26d2833c8a8cbf6](https://github.com/user-attachments/assets/c59818c2-d22b-47b1-9f58-e49c6972c620)

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
