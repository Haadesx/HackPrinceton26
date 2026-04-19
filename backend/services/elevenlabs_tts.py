from __future__ import annotations

import os
from io import BytesIO
from typing import Any

import numpy as np
import soundfile as sf
from elevenlabs import ElevenLabs

DEFAULT_VOICE_ID = os.getenv("KOKORO_VOICE", "af_heart")
MAX_TEXT_LENGTH = 500
SAMPLE_RATE = 24000

_kokoro_pipeline: Any | None = None


def _get_kokoro_pipeline():
    global _kokoro_pipeline
    if _kokoro_pipeline is None:
        from kokoro import KPipeline

        _kokoro_pipeline = KPipeline(lang_code=os.getenv("KOKORO_LANG_CODE", "a"))
    return _kokoro_pipeline


def get_stt_client() -> ElevenLabs:
    api_key = os.getenv("ELEVENLABS_API_KEY")
    if not api_key or api_key == "your_elevenlabs_key_here":
        raise RuntimeError("ELEVENLABS_API_KEY not configured for transcription")
    return ElevenLabs(api_key=api_key)


def text_to_speech(text: str, voice_id: str | None = None) -> bytes:
    """Convert text to speech audio bytes using Kokoro."""
    text = text.strip()
    if not text:
        raise ValueError("Text cannot be empty")

    if len(text) > MAX_TEXT_LENGTH:
        text = text[:MAX_TEXT_LENGTH]

    pipeline = _get_kokoro_pipeline()
    generator = pipeline(
        text,
        voice=voice_id or DEFAULT_VOICE_ID,
        speed=float(os.getenv("KOKORO_SPEED", "1.0")),
    )

    chunks: list[np.ndarray] = []
    for _gs, _ps, audio in generator:
        arr = np.asarray(audio, dtype=np.float32)
        if arr.size:
            chunks.append(arr)

    if not chunks:
        raise RuntimeError("Kokoro did not return audio")

    waveform = np.concatenate(chunks)
    buffer = BytesIO()
    sf.write(buffer, waveform, SAMPLE_RATE, format="WAV")
    return buffer.getvalue()
