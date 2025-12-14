-- Миграция для создания таблицы books
-- Создана: $(date)

CREATE TABLE IF NOT EXISTS books (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    child_id UUID NOT NULL REFERENCES children(id) ON DELETE CASCADE,

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

-- Создание индекса для быстрого поиска книг по child_id
CREATE INDEX IF NOT EXISTS idx_books_child_id ON books(child_id);

-- Создание индекса для быстрого поиска книг по статусу
CREATE INDEX IF NOT EXISTS idx_books_status ON books(status);

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

