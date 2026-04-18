"""Graph router for concept extraction and initial graph data."""

import json
import re
from fastapi import APIRouter, HTTPException

from models.schemas import (
    GraphExtractRequest,
    GraphExtractResponse,
    InitialGraphResponse,
    ConceptNode,
    ConceptEdge,
)
from services.k2 import k2_service
from prompts.context_builder import build_concept_extract_prompt
from prompts.concept_extract import build_concept_extract_prompt

try:
    from data.courses import COURSES
    from data.concepts import CONCEPTS
    from data.connections import CONNECTIONS
except ImportError:
    COURSES = []
    CONCEPTS = []
    CONNECTIONS = []

router = APIRouter()


def _find_course(course_id: str) -> dict:
    for c in COURSES:
        if c["id"] == course_id:
            return c
    return {"id": course_id, "name": course_id.upper(), "topics": []}


def _try_parse_json(text: str) -> dict | None:
    """Extract JSON object from potentially prose-wrapped model output."""
    text = text.strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    # Find first balanced { ... } block
    for match in sorted(re.findall(r'\{[\s\S]*\}', text), key=len, reverse=True):
        try:
            return json.loads(match)
        except json.JSONDecodeError:
            continue
    return None


@router.get("/graph/initial", response_model=InitialGraphResponse)
async def get_initial_graph():
    """Return the pre-built concept graph from mock data (Person 3's data layer)."""
    nodes = [
        ConceptNode(
            id=c["id"],
            label=c["label"],
            course_id=c["course_id"],
            description=c["description"],
        )
        for c in CONCEPTS
    ]
    edges = [
        ConceptEdge(
            source=conn["source"],
            target=conn["target"],
            relationship=conn["relationship"],
        )
        for conn in CONNECTIONS
    ]
    return InitialGraphResponse(nodes=nodes, edges=edges)


@router.post("/graph/extract", response_model=GraphExtractResponse)
async def extract_concepts(request: GraphExtractRequest):
    """
    Extract concept nodes and edges from text using K2 Think V2.
    """
    if not request.text.strip():
        raise HTTPException(status_code=400, detail="Text cannot be empty")

    course = _find_course(request.course_id)

    graph_prompt = build_concept_extract_prompt(
        text=request.text,
        course_id=request.course_id,
        course_name=course.get("name", ""),
    )

    gemini_fallback_prompt = build_concept_extract_prompt(
        text=request.text,
        course_id=request.course_id,
        course_name=course.get("name", ""),
    )

    try:
        result = None

        try:
            result = await k2_service.generate_json(
                graph_prompt,
                system_instruction="Extract academic concepts as valid JSON only.",
            )
        except json.JSONDecodeError:
            raw = await k2_service.generate_text(
                gemini_fallback_prompt,
                system_instruction="Extract academic concepts as valid JSON only.",
            )
            result = _try_parse_json(raw)

        if result is None:
            raise ValueError("Model did not return parseable JSON")

        nodes_data = result.get("nodes", [])
        edges_data = result.get("edges", [])

        nodes = [
            ConceptNode(
                id=n["id"],
                label=n["label"],
                course_id=n.get("course_id", request.course_id),
                description=n["description"],
            )
            for n in nodes_data
        ]

        node_ids = {n.id for n in nodes}
        edges = [
            ConceptEdge(
                source=e["source"],
                target=e["target"],
                relationship=e["relationship"],
            )
            for e in edges_data
            if e["source"] in node_ids and e["target"] in node_ids
        ]

        return GraphExtractResponse(nodes=nodes, edges=edges)

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Concept extraction failed: {e}")
