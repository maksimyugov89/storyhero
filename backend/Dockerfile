FROM python:3.11-slim

WORKDIR /app

# Устанавливаем системные зависимости для OpenCV, InsightFace и других библиотек
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    python3-dev \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    wget \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Копируем requirements
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# Копируем остальной проект
COPY . .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
