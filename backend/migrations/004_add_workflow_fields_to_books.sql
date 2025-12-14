-- Миграция для добавления полей workflow в таблицу books
-- Добавляет: final_pdf_url, images_final, edit_history, detail_prompt
-- Обновляет: status (NOT NULL DEFAULT 'draft')

ALTER TABLE books 
ADD COLUMN IF NOT EXISTS final_pdf_url TEXT,
ADD COLUMN IF NOT EXISTS images_final JSONB,
ADD COLUMN IF NOT EXISTS edit_history JSONB,
ADD COLUMN IF NOT EXISTS detail_prompt TEXT;

-- Убеждаемся, что status имеет дефолтное значение
ALTER TABLE books 
ALTER COLUMN status SET DEFAULT 'draft';

-- Если статус NULL, устанавливаем 'draft'
UPDATE books SET status = 'draft' WHERE status IS NULL;

-- Делаем status NOT NULL (только если все записи имеют значение)
ALTER TABLE books 
ALTER COLUMN status SET NOT NULL;

