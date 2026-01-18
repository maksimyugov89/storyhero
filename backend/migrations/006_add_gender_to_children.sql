-- Миграция: Добавление поля gender (пол) в таблицу children
-- Дата: 2025-12-28
-- Описание: Добавляет обязательное поле gender для правильной генерации изображений персонажей

-- Шаг 1: Добавляем колонку gender (пока nullable для существующих записей)
ALTER TABLE children ADD COLUMN IF NOT EXISTS gender VARCHAR(10);

-- Шаг 2: Устанавливаем значение по умолчанию для существующих записей
-- Используем 'male' как значение по умолчанию
UPDATE children SET gender = 'male' WHERE gender IS NULL;

-- Шаг 3: Делаем поле обязательным (NOT NULL)
ALTER TABLE children ALTER COLUMN gender SET NOT NULL;

-- Шаг 4: Добавляем ограничение CHECK для валидации значений
ALTER TABLE children ADD CONSTRAINT check_gender CHECK (gender IN ('male', 'female'));

-- Шаг 5: Создаем индекс для быстрого поиска (опционально)
CREATE INDEX IF NOT EXISTS idx_children_gender ON children(gender);




