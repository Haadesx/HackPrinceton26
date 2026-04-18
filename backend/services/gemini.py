"""
Gemini AI Service
=================
In the current Syllara architecture, Gemini has TWO roles:

  1. CONTEXT BUILDER (primary): Takes raw mock data (courses, assignments, notes)
     and generates a rich knowledge document for the reasoning stack.

  2. FALLBACK (secondary): If the primary reasoning path is unavailable or fails to return valid JSON
     for structured outputs (flashcards, quiz, concepts), Gemini answers directly.

Gemini does NOT answer final user-facing questions in the primary path.
"""

import json
import os
from typing import Any

try:
    from google import genai
    from google.genai import types
except ImportError:  # pragma: no cover - depends on local package install
    genai = None
    types = None

MODEL = os.getenv("GEMINI_MODEL", os.getenv("VISION_FALLBACK_MODEL", "gemini-2.5-flash"))


def _get_api_key() -> str:
    return (
        os.getenv("GEMINI_API_KEY")
        or os.getenv("GOOGLE_AI_API_KEY")
        or ""
    ).strip()


def gemini_ready() -> bool:
    api_key = _get_api_key()
    return bool(genai and types and api_key and api_key != "your_key_here")


def get_client() -> genai.Client:
    """Get a configured Gemini client. Raises RuntimeError if key not set."""
    api_key = _get_api_key()
    if not genai or not types:
        raise RuntimeError("google-genai is not installed. Add it to backend requirements to enable Gemini fallback.")
    if not api_key or api_key == "your_key_here":
        raise RuntimeError("Gemini fallback key not set. Add GEMINI_API_KEY or GOOGLE_AI_API_KEY to backend/.env")
    return genai.Client(api_key=api_key)


# ─── Primary Role: Context Building ──────────────────────────────────────────

async def build_knowledge_document(prompt: str) -> str:
    """
    Use Gemini to generate a comprehensive knowledge document from raw student data.
    This document is uploaded as a knowledge source.

    Args:
        prompt: The context_builder.build_knowledge_document_prompt() output

    Returns:
        A well-structured text document ready to be uploaded into platform context
    """
    client = get_client()

    response = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Content(
                role="user",
                parts=[types.Part.from_text(text=prompt)],
            )
        ],
        config=types.GenerateContentConfig(
            system_instruction=(
                "You are creating a knowledge document for an AI agent. "
                "Be thorough, specific, and well-organized. "
                "Use clear headings and structure."
            ),
            temperature=0.3,  # Lower temp for factual document
            max_output_tokens=4096,
        ),
    )

    return response.text


# ─── Fallback Role: Direct JSON Generation ────────────────────────────────────

async def generate_json_fallback(prompt: str, system_instruction: str = "") -> Any:
    """
    FALLBACK: Generate structured JSON directly from Gemini.
    Used when the primary reasoning path is down or returns non-JSON for flashcards/quiz/concepts.

    Returns a parsed Python object (dict or list).
    """
    client = get_client()

    full_prompt = (
        prompt + "\n\nIMPORTANT: Respond with valid JSON only. "
        "No markdown fences, no explanation."
    )

    response = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Content(
                role="user",
                parts=[types.Part.from_text(text=full_prompt)],
            )
        ],
        config=types.GenerateContentConfig(
            system_instruction=system_instruction
            or "You are an AI that outputs valid JSON only.",
            temperature=0.7,
            max_output_tokens=4096,
            response_mime_type="application/json",
        ),
    )

    text = response.text.strip()

    # Strip markdown fences if model wrapped output anyway
    if text.startswith("```"):
        lines = text.split("\n")
        lines = [l for l in lines if not l.strip().startswith("```")]
        text = "\n".join(lines)

    return json.loads(text)


async def generate_text_fallback(prompt: str, system_instruction: str = "") -> str:
    """
    FALLBACK: Generate a plain-text response directly from Gemini.
    Used when the primary reasoning path is down for study guide generation.
    """
    client = get_client()

    response = client.models.generate_content(
        model=MODEL,
        contents=[
            types.Content(
                role="user",
                parts=[types.Part.from_text(text=prompt)],
            )
        ],
        config=types.GenerateContentConfig(
            system_instruction=system_instruction
            or "You are a helpful academic AI assistant.",
            temperature=0.7,
            max_output_tokens=4096,
        ),
    )

    return response.text
