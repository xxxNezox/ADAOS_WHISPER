#!/bin/bash

# 1. Клонирование репозитория (версия v1.7.4 для стабильности)
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

# 2. Установка зависимостей (для Ubuntu/Debian)
# sudo apt update && sudo apt install -y build-essential cmake libsdl2-dev ffmpeg

# 3. Сборка проекта
mkdir -p build && cd build
cmake .. && make

# 4. Загрузка базовой многоязычной модели (поддерживает русский)
cd ..
./models/download-ggml-model.sh base

# 5. Квантование модели в формат q8_0 для ускорения
./build/bin/quantize ./models/ggml-base.bin ./models/ggml-base-q8_0.bin q8_0

# 6. Проверка работоспособности (необязательно)
echo "Тестовая транскрипция:"
./build/bin/whisper-cli -m ./models/ggml-base-q8_0.bin -l ru -f ./samples/jfk.wav