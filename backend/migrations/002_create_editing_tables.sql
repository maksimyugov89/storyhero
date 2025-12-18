-- Миграция для создания таблиц редактирования книг
-- Версии текста и изображений

-- Таблица версий текста
CREATE TABLE IF NOT EXISTS text_versions (
    id SERIAL PRIMARY KEY,
    scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    scene_order INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    text TEXT NOT NULL,
    edit_instruction TEXT,
    is_selected BOOLEAN NOT NULL DEFAULT FALSE,
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_scene_text_version UNIQUE (book_id, scene_id, version_number)
);

COMMENT ON TABLE text_versions IS 'Версии текста для сцен. Максимум 5 редактирований + 1 оригинал (0-5).';
COMMENT ON COLUMN text_versions.version_number IS 'Номер версии (0 = оригинал, 1-5 = редактирования)';
COMMENT ON COLUMN text_versions.is_selected IS 'Выбрана ли эта версия пользователем';
COMMENT ON COLUMN text_versions.is_original IS 'Является ли это оригинальной версией';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_text_versions_book_scene ON text_versions(book_id, scene_id);
CREATE INDEX IF NOT EXISTS idx_text_versions_selected ON text_versions(book_id, scene_id, is_selected) WHERE is_selected = TRUE;

-- Таблица версий изображений
CREATE TABLE IF NOT EXISTS image_versions (
    id SERIAL PRIMARY KEY,
    image_id INTEGER NOT NULL REFERENCES images(id) ON DELETE CASCADE,
    scene_id INTEGER NOT NULL REFERENCES scenes(id) ON DELETE CASCADE,
    book_id UUID NOT NULL REFERENCES books(id) ON DELETE CASCADE,
    scene_order INTEGER NOT NULL,
    version_number INTEGER NOT NULL,
    image_url TEXT NOT NULL,
    edit_instruction TEXT,
    is_selected BOOLEAN NOT NULL DEFAULT FALSE,
    is_original BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    CONSTRAINT unique_scene_image_version UNIQUE (book_id, scene_id, version_number)
);

COMMENT ON TABLE image_versions IS 'Версии изображений для сцен. Максимум 3 редактирования + 1 оригинал (0-3).';
COMMENT ON COLUMN image_versions.version_number IS 'Номер версии (0 = оригинал, 1-3 = редактирования)';
COMMENT ON COLUMN image_versions.is_selected IS 'Выбрано ли это изображение пользователем';
COMMENT ON COLUMN image_versions.is_original IS 'Является ли это оригинальным изображением';

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_image_versions_book_scene ON image_versions(book_id, scene_id);
CREATE INDEX IF NOT EXISTS idx_image_versions_selected ON image_versions(book_id, scene_id, is_selected) WHERE is_selected = TRUE;

