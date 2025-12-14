# StoryHero App

Flutter приложение для создания персонализированных детских книг.

## Структура проекта

```
lib/
  app.dart                    # Главный виджет приложения
  main.dart                   # Точка входа
  router/
    app_router.dart          # Настройка роутинга с GoRouter
  features/
    auth/                    # Аутентификация
      data/
        auth_repository.dart # Репозиторий для работы с Supabase Auth
      presentation/
        login_screen.dart
        register_screen.dart
        loading_screen.dart
    children/                # Управление детьми
      presentation/
        children_list_screen.dart
        child_create_screen.dart
    books/                   # Просмотр книг
      presentation/
        books_list_screen.dart
        book_view_screen.dart
    generate/                # Генерация книг
      presentation/
        create_book_screen.dart
        task_status_screen.dart
  core/
    api/
      api_client.dart        # Настройка Dio с interceptors
      backend_api.dart       # API методы для backend
      supabase_provider.dart # Провайдер Supabase
    models/                  # Модели данных (Freezed)
      user.dart
      child.dart
      book.dart
      scene.dart
      theme_style.dart
      task_status.dart
    theme/
      app_theme.dart         # Светлая и тёмная темы
    widgets/                 # Переиспользуемые виджеты
      error_widget.dart
      loading_widget.dart
      rounded_image.dart
```

## Зависимости

- **hooks_riverpod** - управление состоянием
- **go_router** - навигация
- **dio** - HTTP клиент
- **supabase_flutter** - аутентификация
- **freezed** - генерация кода для моделей
- **cached_network_image** - кеширование изображений

## Настройка

### 1. Backend URL

Откройте `lib/core/api/api_client.dart` и замените `baseUrl` на адрес вашего backend:

```dart
const String baseUrl = 'http://YOUR_IP_OR_DOMAIN:8000';
```

### 2. Генерация кода

После установки зависимостей выполните:

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

Это сгенерирует файлы для Freezed моделей (`.freezed.dart`, `.g.dart`).

### 3. Сборка

#### Web
```bash
flutter build web
```

#### Android
```bash
flutter build apk
```

## API Endpoints

Backend должен предоставлять следующие эндпоинты:

- `GET /auth_config` - получение конфигурации Supabase
- `POST /children` - создание ребёнка
- `GET /children` - список детей
- `GET /books` - список книг
- `GET /books/:bookId/scenes` - сцены книги
- `POST /generate_full_book` - генерация книги
- `GET /books/task_status/:taskId` - статус задачи
- `POST /regenerate_scene` - перегенерация сцены
- `POST /select_style` - выбор стиля

## Особенности

- ✅ Аутентификация через Supabase
- ✅ Автоматическое добавление JWT токена в запросы
- ✅ Обработка 401 ошибок (автоматический выход)
- ✅ Polling статуса задач генерации
- ✅ Адаптивный UI для мобильных и web
- ✅ Светлая и тёмная темы
- ✅ Красивый UI с закруглёнными карточками и тенями

## Запуск

```bash
flutter run -d chrome  # Web
flutter run             # Android/iOS (по умолчанию)
```

## Структура данных

### Child
```dart
{
  "id": "string",
  "name": "string",
  "age": 5,
  "interests": ["спорт", "рисование"],
  "fears": ["темнота"],
  "personality": "описание",
  "moral": "мораль истории",
  "face_url": "string?" 
}
```

### Book
```dart
{
  "id": "string",
  "title": "string",
  "child_id": "string",
  "user_id": "string",
  "created_at": "ISO 8601 datetime"
}
```

### Scene
```dart
{
  "id": "string",
  "book_id": "string",
  "order": 1,
  "short_summary": "string",
  "image_prompt": "string",
  "draft_url": "string?",
  "final_url": "string?"
}
```

## TODO

- [ ] Загрузка изображений на сервер (получение faceUrl)
- [ ] Редактирование детей
- [ ] Удаление книг
- [ ] Поделиться книгой
- [ ] Экспорт книги в PDF
