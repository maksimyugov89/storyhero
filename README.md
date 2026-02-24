# <img width="256" alt="icon" src="https://github.com/user-attachments/assets/bc0704c8-8342-4c96-ac48-06631abec4cc" /> StoryHero

StoryHero — это мобильное приложение для создания персонализированных детских книг с помощью искусственного интеллекта.

Проект состоит из Flutter-клиента и FastAPI-бэкенда, объединённых в единый monorepo.

## Скриншоты 

<p float="left">
  <img src="https://github.com/user-attachments/assets/1557feb7-54cc-4e06-811c-2244eb7e78dd" alt="screenshot 1" width="260" />
  <img src="https://github.com/user-attachments/assets/990d0a51-cc17-40bd-9ec7-0d586217abd0" alt="screenshot 2" width="260" />
  <img src="https://github.com/user-attachments/assets/4fb876cf-8404-4f9e-acb4-7d2a94347a66" alt="screenshot 3" width="260" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/4897d670-5412-438c-acc5-04aec43e348d" alt="screenshot 4" width="260" />
  <img src="https://github.com/user-attachments/assets/8ba99fb5-6478-4b07-bd3a-3859816eda12" alt="screenshot 5" width="260" />
  <img src="https://github.com/user-attachments/assets/75064a58-9e15-4eb4-afbe-f7fd912e47b2" alt="screenshot 6" width="260" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/78434254-7de0-4ad9-9035-8872748f5b36" alt="screenshot 7" width="260" />
  <img src="https://github.com/user-attachments/assets/e541aa4d-8a71-449e-92df-6e8a73453c76" alt="screenshot 8" width="260" />
  <img src="https://github.com/user-attachments/assets/f31a47eb-6df5-445d-956d-02964a796707" alt="screenshot 9" width="260" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/0b5c2ef9-0c6c-4b77-be66-aecef092f532" alt="screenshot 10" width="260" />
  <img src="https://github.com/user-attachments/assets/91bab22a-1e87-46f6-b4e7-f784ad45948f" alt="screenshot 11" width="260" />
  <img src="https://github.com/user-attachments/assets/3357dc08-5c4e-4ba9-96b3-51f5cdbb3e5e" alt="screenshot 12" width="260" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/e315cc54-151d-4575-9694-ad72adea4023" alt="screenshot 13" width="260" />
  <img src="https://github.com/user-attachments/assets/9f7a60f5-06f3-4463-8c10-0ce7dec9023a" alt="screenshot 14" width="260" />
  <img src="https://github.com/user-attachments/assets/9b30e77a-e956-4fbe-8c37-ee19737e5688" alt="screenshot 15" width="260" />
</p>

<p float="left">
  <img src="https://github.com/user-attachments/assets/8d63b028-fa47-4c2b-8418-4c1d6b53db95" alt="screenshot 16" width="260" />
  <img src="https://github.com/user-attachments/assets/62f35f15-c702-4154-aec7-b6a9c2954e89" alt="screenshot 17" width="260" />
  <img src="https://github.com/user-attachments/assets/c59818c2-d22b-47b1-9f58-e49c6972c620" alt="screenshot 18" width="260" />
</p>

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
cd frontend
flutter pub get
flutter run
