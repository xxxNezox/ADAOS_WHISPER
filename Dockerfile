# ==================== Билдер-этап ====================
FROM ubuntu:24.04 AS builder

# Установка зависимостей для сборки
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    libsdl2-dev \
    ffmpeg \
    python3 \
    python3-pip \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 1. Клонирование репозитория с фиксацией версии
RUN git clone https://github.com/ggerganov/whisper.cpp.git \
    && cd whisper.cpp 

# 2. Сборка проекта
RUN cd whisper.cpp \
    && mkdir -p build \
    && cd build \
    && cmake .. \
    && make

# 3. Загрузка и квантование модели
RUN cd whisper.cpp \
    && ./models/download-ggml-model.sh base \
    && ./build/bin/quantize ./models/ggml-base.bin ./models/ggml-base-q8_0.bin q8_0

# ==================== Финальный образ ====================
FROM ubuntu:24.04

# Установка runtime зависимостей + venv
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libsdl2-2.0-0 \
    python3 \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем whisper.cpp и удаляем исходную модель
COPY --from=builder /app/whisper.cpp/ ./whisper.cpp/
RUN rm -f ./whisper.cpp/models/ggml-base.bin

# Создаем и активируем виртуальное окружение
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Копируем исходный код приложения
COPY app.py requirements.txt ./

# Установка зависимостей в виртуальное окружение
RUN pip install --no-cache-dir -r requirements.txt

# Настройка окружения
ENV WHISPER_CLI_PATH="/app/whisper.cpp/build/bin/whisper-cli"
ENV MODEL_PATH="/app/whisper.cpp/models/ggml-base-q8_0.bin"

EXPOSE 8000
CMD ["python3", "app.py"]