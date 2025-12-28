-- Миграция для создания таблиц системы поддержки
-- Создана: 2025-12-28

-- Таблица для сообщений пользователей в поддержку
CREATE TABLE IF NOT EXISTS support_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,  -- 'suggestion', 'bug', 'question'
    message TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'new',  -- 'new', 'answered', 'closed'
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Таблица для ответов на сообщения поддержки
CREATE TABLE IF NOT EXISTS support_message_replies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES support_messages(id) ON DELETE CASCADE,
    reply_text TEXT NOT NULL,
    replied_by VARCHAR(255),  -- 'telegram', 'admin_user_id', 'user_{user_id}'
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Создание индексов для support_messages
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_status ON support_messages(status);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at DESC);

-- Создание индексов для support_message_replies
CREATE INDEX IF NOT EXISTS idx_support_replies_message_id ON support_message_replies(message_id);
CREATE INDEX IF NOT EXISTS idx_support_replies_is_read ON support_message_replies(is_read);
CREATE INDEX IF NOT EXISTS idx_support_replies_created_at ON support_message_replies(created_at DESC);

-- Триггер для автоматического обновления updated_at в support_messages
CREATE OR REPLACE FUNCTION update_support_messages_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_support_messages_updated_at BEFORE UPDATE ON support_messages
    FOR EACH ROW EXECUTE FUNCTION update_support_messages_updated_at();

