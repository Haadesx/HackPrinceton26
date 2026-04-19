"""Chat router powered by K2 Think V2."""

import json
import re
from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse

from models.schemas import ChatRequest
from services.k2 import k2_service, K2Error
from prompts.context_builder import build_chat_prompt
from prompts.chat_system import build_chat_system_prompt

# Import mock data (populated by Person 3)
try:
    from data.courses import COURSES
    from data.assignments import ASSIGNMENTS
    from data.notes import NOTES
except ImportError:
    COURSES = []
    ASSIGNMENTS = []
    NOTES = []

router = APIRouter()


LEAK_PATTERNS = [
    r"^we have\b",
    r"^the user says:\b",
    r"^\s*student question:\b",
    r"^\s*previous conversation:\b",
    r"^\s*the system says\b",
    r"^\s*assistant is supposed to\b",
    r"^\s*we need to\b",
    r"^\s*that is ambiguous\b",
    r"^\s*they didn't specify\b",
    r"\bhidden reasoning\b",
    r"\bchain[- ]of[- ]thought\b",
]


def _looks_like_reasoning_leak(text: str) -> bool:
    lowered = text.lower()
    return any(re.search(pattern, lowered) for pattern in LEAK_PATTERNS)


def _clean_chat_response(text: str) -> str:
    cleaned = text.strip()
    if not cleaned:
        return ""

    cleaned = re.sub(r"^```(?:markdown)?\s*", "", cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r"\s*```$", "", cleaned)
    cleaned = re.sub(r"(?is)<think>[\s\S]*?</think>", "", cleaned).strip()

    if "</think>" in cleaned:
        cleaned = cleaned.split("</think>")[-1].strip()

    if cleaned.lower().startswith("the user says:"):
        for marker in ("\n## ", "\n### ", "\n**", "\nIn ", "\nGeneralization", "\nWhat ", "\nFor "):
            idx = cleaned.find(marker)
            if idx != -1:
                cleaned = cleaned[idx + 1 :].strip()
                break

    meta_prefixes = (
        "the user says:",
        "we need to",
        "thus we need to",
        "we must",
        "we will produce",
        "ok.",
        "we'll produce",
        "thus final answer",
    )
    lines = cleaned.splitlines()
    while lines and lines[0].strip().lower().startswith(meta_prefixes):
        lines.pop(0)
    cleaned = "\n".join(lines).strip()

    return cleaned


def _safe_fallback_reply(
    user_message: str,
    course_context: str | None,
    upcoming_deadlines: list[dict] | None = None,
) -> str:
    cleaned = user_message.strip()
    if not cleaned:
        return "What would you like help with?"

    lowered = cleaned.lower()
    if upcoming_deadlines and any(
        phrase in lowered
        for phrase in ("today", "hit list", "what do we have", "what's due", "what is due", "priority", "priorities")
    ):
        top_items = []
        for item in upcoming_deadlines[:4]:
            course = item.get("course_code") or item.get("course_id", "").upper()
            title = item.get("title", "Assignment")
            days_left = item.get("days_left")
            when = "today" if days_left == 0 else "tomorrow" if days_left == 1 else f"in {days_left} days"
            if isinstance(days_left, (int, float)) and days_left < 0:
                when = "overdue"
            top_items.append(f"- `{course}`: {title} ({when})")
        if top_items:
            return "Here’s the current hit list:\n" + "\n".join(top_items)

    short_ambiguous = {"elaborate", "explain more", "more", "clarify", "why"}
    if lowered in short_ambiguous:
        if course_context:
            return f"What would you like me to elaborate on in {course_context.upper()}?"
        return "What would you like me to elaborate on?"

    return "Could you clarify the specific part you want me to explain?"


@router.post("/chat")
async def chat(request: ChatRequest):
    """Main chat endpoint."""
    if not request.messages:
        raise HTTPException(status_code=400, detail="Messages list cannot be empty")

    # The latest user message
    last_message = request.messages[-1].content
    history = [
        {"role": m.role, "content": m.content}
        for m in request.messages[:-1]  # all except last
    ]

    # Map raw assignment IDs to their human-readable names so the model sees stable labels
    named_triage = {}
    if request.triage_statuses:
        for aid, stat in request.triage_statuses.items():
            assignment = next((a for a in ASSIGNMENTS if a.get("id") == aid), None)
            name = assignment.get("name", aid) if assignment else aid
            named_triage[name] = stat

    prompt = build_chat_prompt(
        user_question=last_message,
        conversation_history=history if history else None,
        triage_statuses=named_triage,
        system_status=request.system_status,
        active_remediation=request.active_remediation,
        upcoming_deadlines=request.upcoming_deadlines,
        graph_context=request.graph_context,
        graph_connections=request.graph_connections,
    )

    async def event_stream():
        try:
            system_prompt = build_chat_system_prompt(
                courses=COURSES,
                assignments=ASSIGNMENTS,
                notes=NOTES,
                course_filter=request.course_context,
                triage_statuses=request.triage_statuses,
                active_remediation=request.active_remediation,
            )

            if request.agent_url:
                response_text = await k2_service.send_prompt_to_agent(
                    request.agent_url,
                    prompt,
                    system_instruction=system_prompt,
                )
            else:
                response_text = await k2_service.send_prompt(
                    prompt,
                    system_instruction=system_prompt,
                )

            response_text = _clean_chat_response(response_text)

            if not response_text or _looks_like_reasoning_leak(response_text):
                response_text = _safe_fallback_reply(
                    last_message,
                    request.course_context,
                    request.upcoming_deadlines,
                )
        except K2Error as e:
            err = json.dumps({"error": f"K2 request failed: {str(e)}"})
            yield f"data: {err}\n\n"
            yield "data: [DONE]\n\n"
            return

        chunk_size = 50  # characters per chunk
        for i in range(0, len(response_text), chunk_size):
            chunk = response_text[i : i + chunk_size]
            data = json.dumps({"content": chunk})
            yield f"data: {data}\n\n"

        yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )
