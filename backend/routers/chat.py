"""Chat router powered by K2 Think V2."""

import json
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
