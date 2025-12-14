-- Миграция для создания таблицы books с совместимостью
-- child_id использует INTEGER для совместимости с существующей таблицей children
-- id книги использует UUID для новых записей

-- Удаляем старую таблицу (если она существует со старой структурой)
DROP TABLE IF EXISTS books CASCADE;

-- Создаем новую таблицу
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id INTEGER NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    user_id TEXT,  -- UUID из Supabase auth.users (для совместимости)

    title TEXT NOT NULL,
    description TEXT,

    genre TEXT,
    theme TEXT,
    writing_style TEXT,
    narrator TEXT,

    cover_url TEXT,

    content TEXT,
    pages JSONB,
    prompt TEXT,
    ai_model TEXT,
    variables_used JSONB,
    audio_url TEXT,

    status TEXT DEFAULT 'draft',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создание индексов
CREATE INDEX idx_books_child_id ON books(child_id);
CREATE INDEX idx_books_status ON books(status);

-- Триггер для автоматического обновления updated_at
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_books_updated_at BEFORE UPDATE ON books
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

