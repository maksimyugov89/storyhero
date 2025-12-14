-- Миграция для обновления таблицы books: Integer -> UUID
-- ВНИМАНИЕ: Эта миграция удаляет старую таблицу и создает новую
-- Используйте только если в таблице books НЕТ важных данных

-- Удаляем старую таблицу (внимание: данные будут потеряны!)
DROP TABLE IF EXISTS books CASCADE;

-- Создаем новую таблицу с правильной структурой
CREATE TABLE books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,
    user_id TEXT,  -- Для совместимости со старым кодом

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

