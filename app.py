from flask import Flask, request, jsonify
import subprocess
import tempfile
import os
from functools import lru_cache

app = Flask(__name__)

WHISPER_CLI_PATH = "/app/whisper.cpp/build/bin/whisper-cli"
MODEL_PATH = "/app/whisper.cpp/models/ggml-base-q8_0.bin"

@lru_cache(maxsize=100)
def transcribe_audio(audio_file: str) -> str:
    """
    Выполняет транскрипцию аудиофайла с помощью whisper-cli.
    """
    result = subprocess.run(
        [
            WHISPER_CLI_PATH,
            "-m", MODEL_PATH,
            "-l", "ru",
            "-f", audio_file,
            "--output-txt",
            "--no-timestamps",
            "--no-prints"
        ],
        capture_output=True,
        text=True,
        check=True
    )
    return result.stdout.strip()

@app.route("/transcribe", methods=["POST"])
def transcribe():
    """
    Эндпоинт для загрузки аудиофайла и его транскрипции.
    """
    # Проверка наличия файла в запросе
    if "file" not in request.files:
        return jsonify({"error": "Файл не найден в запросе"}), 400
    
    file = request.files["file"]
    
    # Проверка размера файла (максимум 25 МБ)
    max_file_size = 25 * 1024 * 1024
    file.seek(0, os.SEEK_END)
    file_size = file.tell()
    file.seek(0)
    if file_size > max_file_size:
        return jsonify({"error": "Файл слишком большой. Максимальный размер — 25 МБ."}), 400
    
    # Сохраняем файл во временный файл
    with tempfile.NamedTemporaryFile(delete=True, suffix=".wav") as tmp:
        file.save(tmp.name)
        
        # Если файл не в формате WAV, конвертируем его
        if not file.filename.endswith(".wav"):
            converted_file = tempfile.NamedTemporaryFile(delete=True, suffix=".wav")
            subprocess.run(
                [
                    "ffmpeg",
                    "-y",
                    "-i", tmp.name,
                    "-ar", "16000",
                    "-ac", "1",
                    "-c:a", "pcm_s16le",
                    converted_file.name
                ],
                check=True
            )
            audio_file = converted_file.name
        else:
            audio_file = tmp.name
        
        try:
            result = transcribe_audio(audio_file)
        except subprocess.CalledProcessError as e:
            return jsonify({"error": f"Ошибка при обработке аудио: {e.stderr}"}), 500
        
        cleaned_text = " ".join(result.split())
        
        return jsonify({"text": cleaned_text})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)