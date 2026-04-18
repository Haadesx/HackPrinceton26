"""Generation router powered by K2 Think V2."""

import json
import re
from fastapi import APIRouter, HTTPException

from models.schemas import (
    GenerateRequest,
    StudyGuideResponse,
    FlashcardsResponse,
    FlashCard,
    QuizResponse,
    QuizQuestion,
)
from services.k2 import k2_service
from services.gemini import generate_text_fallback, gemini_ready
from prompts.context_builder import (
    build_study_guide_generation_prompt,
    build_flashcards_generation_prompt,
    build_quiz_generation_prompt,
)
from prompts.study_guide import build_study_guide_prompt
from prompts.flashcards import build_flashcards_prompt
from prompts.quiz import build_quiz_prompt

try:
    from data.courses import COURSES
except ImportError:
    COURSES = []

router = APIRouter()


def _find_course(course_id: str) -> dict:
    for c in COURSES:
        if c["id"] == course_id:
            return c
    return {"id": course_id, "name": course_id.upper(), "topics": ["general topics"]}


def _sanitize_json_string(text: str) -> str:
    """Remove control characters that break JSON parsing (common in LLM output)."""
    import re
    # Replace literal newlines/tabs/carriage-returns with their escaped forms
    # This handles the most common LLM issue: newlines inside JSON string values
    text = text.replace('\r\n', '\\n').replace('\r', '\\n').replace('\n', '\\n').replace('\t', '\\t')
    # Remove any other control chars (0x00-0x1F) that aren't valid in JSON
    text = re.sub(r'[\x00-\x08\x0b\x0c\x0e-\x1f]', ' ', text)
    return text


def _try_parse_json(text: str) -> dict | list | None:
    """Try to parse JSON from model response text even when prose leaks around it."""
    text = text.strip()

    # Try direct parse
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # Sanitize control characters and retry
    sanitized = _sanitize_json_string(text)
    try:
        return json.loads(sanitized)
    except json.JSONDecodeError:
        pass

    decoder = json.JSONDecoder()

    # Prefer likely payload starts near the end of the response where K2 often emits the final JSON.
    preferred_markers = [
        '{"questions"',
        '{"cards"',
        '{"nodes"',
        '{"edges"',
        '{"course',
        '{"content"',
    ]
    candidate_positions: list[int] = []
    for marker in preferred_markers:
        idx = sanitized.rfind(marker)
        if idx != -1:
            candidate_positions.append(idx)

    seen: set[int] = set()

    # First, only try strongly preferred wrapper positions.
    for start in sorted(candidate_positions, reverse=True):
        if start in seen:
            continue
        seen.add(start)
        try:
            parsed, _end = decoder.raw_decode(sanitized[start:])
            if isinstance(parsed, (dict, list)):
                return parsed
        except json.JSONDecodeError:
            continue

    # Fall back to scanning any JSON-ish opening token from right to left.
    fallback_positions = [i for i, ch in enumerate(sanitized) if ch in "{["]
    for start in sorted(fallback_positions, reverse=True):
        if start in seen:
            continue
        seen.add(start)
        try:
            parsed, _end = decoder.raw_decode(sanitized[start:])
            if isinstance(parsed, (dict, list)):
                return parsed
        except json.JSONDecodeError:
            continue

    return None


def _extract_questions_payload(result: dict | list) -> list[dict]:
    if isinstance(result, dict):
        if isinstance(result.get("questions"), list):
            return result["questions"]
        if "question" in result and isinstance(result.get("options"), list):
            return [result]
    if isinstance(result, list):
        if result and all(isinstance(item, dict) and "question" in item for item in result):
            return result
    raise ValueError("Unexpected quiz format")


def _extract_flashcards_payload(result: dict | list) -> list[dict]:
    if isinstance(result, dict):
        if isinstance(result.get("cards"), list):
            return result["cards"]
        if "front" in result and "back" in result:
            return [result]
    if isinstance(result, list):
        if result and all(isinstance(item, dict) and "front" in item and "back" in item for item in result):
            return result
    raise ValueError("Unexpected flashcard format")


def _clean_study_guide_markdown(text: str) -> str:
    """Remove common model meta-commentary so the guide reads like study material."""
    cleaned = text.strip()

    fence_match = re.match(r"^```(?:markdown)?\s*([\s\S]*?)\s*```$", cleaned, flags=re.IGNORECASE)
    if fence_match:
        cleaned = fence_match.group(1).strip()

    cleaned = re.sub(r"(?is)<think>[\s\S]*?</think>", "", cleaned).strip()
    cleaned = re.sub(r"(?im)^</think>\s*", "", cleaned).strip()

    drop_patterns = [
        r"^here(?:'s| is)\s+(?:a\s+)?study\s+guide[^\n]*\n+",
        r"^let'?s\s+(?:break|walk|go)\s+[^\n]*\n+",
        r"^i(?:'ll| will)\s+[^\n]*\n+",
        r"^below\s+is\s+[^\n]*\n+",
        r"^this\s+study\s+guide[^\n]*\n+",
    ]
    for pattern in drop_patterns:
        cleaned = re.sub(pattern, "", cleaned, flags=re.IGNORECASE)

    lines = cleaned.splitlines()
    while lines and not lines[0].lstrip().startswith(("#", "-", "*", "1.", "2.", "3.")):
        if re.search(r"(study guide|break this down|walk through|explain|overview)", lines[0], flags=re.IGNORECASE):
            lines.pop(0)
            continue
        break

    cleaned = "\n".join(lines).strip()

    heading_match = re.search(r"(?m)^#\s+.+$", cleaned)
    if heading_match:
        cleaned = cleaned[heading_match.start():].strip()

    trailing_markers = [
        r"(?im)^make sure .*",
        r"(?im)^also mention .*",
        r"(?im)^common mistakes:.*",
        r"(?im)^potential pitfalls:.*",
        r"(?im)^now produce final .*",
    ]
    for marker in trailing_markers:
        split_match = re.search(marker, cleaned)
        if split_match:
            cleaned = cleaned[:split_match.start()].strip()

    return cleaned


def _looks_like_student_guide(text: str) -> bool:
    lowered = text.lower()
    bad_signals = [
        "we need to",
        "we must",
        "the user wants",
        "output must",
        "now produce final",
        "make sure",
        "likely the first heading",
        "don't mention being an ai",
        "just produce the study guide",
    ]
    if any(signal in lowered for signal in bad_signals):
        return False

    required_headings = [
        "overview",
        "key concepts",
        "common mistakes",
        "practice problems",
    ]
    if not any(text.lstrip().startswith(prefix) for prefix in ("#", "## ")):
        return False
    if sum(1 for heading in required_headings if heading in lowered) < 3:
        return False
    if len(text.strip()) < 600:
        return False
    return True


async def _generate_text(prompt: str, system: str) -> str:
    return await k2_service.generate_text(prompt, system_instruction=system)


async def _generate_json(prompt: str, system: str) -> dict | list:
    raw = await k2_service.generate_text(
        (
            prompt
            + "\n\nIMPORTANT: Respond with valid JSON only. "
            + "No markdown fences. No explanation."
        ),
        system_instruction=system or "Return valid JSON only.",
    )

    cleaned = raw.strip()
    if cleaned.startswith("```"):
        lines = [line for line in cleaned.splitlines() if not line.strip().startswith("```")]
        cleaned = "\n".join(lines).strip()

    try:
        return json.loads(cleaned)
    except json.JSONDecodeError:
        parsed = _try_parse_json(cleaned)
        if parsed is None:
            raise
        return parsed


# ─── Study Guide ──────────────────────────────────────────────────────────────

@router.post("/generate/study-guide", response_model=StudyGuideResponse)
async def generate_study_guide(request: GenerateRequest):
    """Generate a markdown study guide via K2."""
    course = _find_course(request.course_id)

    base_prompt = build_study_guide_prompt(
        topic=request.topic,
        course_id=request.course_id,
        course_name=course["name"],
        course_topics=course.get("topics", []),
        additional_context=request.additional_context,
    )

    try:
        content = await _generate_text(
            base_prompt,
            system=(
                "You are an expert academic tutor creating polished study materials. "
                "Return only the final student-facing study guide in markdown. "
                "Do not include meta-commentary, self-reference, planning text, hidden reasoning, "
                "prompt restatements, outlines with ellipses, or notes to yourself. "
                "Do not echo instructions. Fill every section with real study content."
            ),
        )
        content = _clean_study_guide_markdown(content)
        if not _looks_like_student_guide(content) and gemini_ready():
            content = await generate_text_fallback(
                base_prompt,
                system_instruction=(
                    "You are an expert academic tutor creating polished study materials. "
                    "Return only the final student-facing study guide in markdown. "
                    "Start directly with markdown headings and fill each section with real content."
                ),
            )
            content = _clean_study_guide_markdown(content)
        return StudyGuideResponse(
            content=content,
            topic=request.topic,
            course_id=request.course_id,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Study guide generation failed: {e}")


# ─── Flashcards ───────────────────────────────────────────────────────────────

@router.post("/generate/flashcards", response_model=FlashcardsResponse)
async def generate_flashcards(request: GenerateRequest):
    """Generate flashcards via K2."""
    course = _find_course(request.course_id)

    generation_prompt = build_flashcards_generation_prompt(
        topic=request.topic,
        course_id=request.course_id,
        course_name=course["name"],
        additional_context=request.additional_context,
    )

    gemini_fallback_prompt = build_flashcards_prompt(
        topic=request.topic,
        course_id=request.course_id,
        course_name=course["name"],
        course_topics=course.get("topics", []),
        additional_context=request.additional_context,
    )

    try:
        result = await _generate_json(
            generation_prompt or gemini_fallback_prompt,
            system="You are an expert academic tutor. Generate flashcards as valid JSON only.",
        )

        cards_data = _extract_flashcards_payload(result)

        cards = [
            FlashCard(
                front=c["front"],
                back=c["back"],
                course_id=request.course_id,
            )
            for c in cards_data
        ]
        return FlashcardsResponse(cards=cards, topic=request.topic, course_id=request.course_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Flashcard generation failed: {e}")


# ─── Quiz ─────────────────────────────────────────────────────────────────────

@router.post("/generate/quiz", response_model=QuizResponse)
async def generate_quiz(request: GenerateRequest):
    """Generate quiz questions via K2."""
    course = _find_course(request.course_id)

    generation_prompt = build_quiz_generation_prompt(
        topic=request.topic,
        course_id=request.course_id,
        course_name=course["name"],
        additional_context=request.additional_context,
    )

    gemini_fallback_prompt = build_quiz_prompt(
        topic=request.topic,
        course_id=request.course_id,
        course_name=course["name"],
        course_topics=course.get("topics", []),
        additional_context=request.additional_context,
    )

    try:
        result = await _generate_json(
            generation_prompt or gemini_fallback_prompt,
            system="You are an expert academic tutor. Generate quiz questions as valid JSON only.",
        )

        questions_data = _extract_questions_payload(result)

        questions = [
            QuizQuestion(
                question=q["question"],
                options=q["options"],
                correct_index=q["correct_index"],
                explanation=q["explanation"],
            )
            for q in questions_data
        ]
        return QuizResponse(questions=questions, topic=request.topic, course_id=request.course_id)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Quiz generation failed: {e}")
