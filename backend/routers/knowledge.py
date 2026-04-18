import logging
from fastapi import APIRouter, HTTPException
from models.schemas import GraphRefreshRequest, KnowledgeContextRequest, CourseRecommendationRequest
from services.k2 import k2_service
from prompts.graph_analysis import build_graph_analysis_prompt
from prompts.topic_knowledge import build_topic_knowledge_prompt
from prompts.course_recommendation import (
    build_course_recommendation_prompt,
    build_recommendation_json_prompt,
)

try:
    from data.courses import COURSES
    from data.assignments import ASSIGNMENTS
    from data.notes import NOTES
    from data.concepts import CONCEPTS
    from data.connections import CONNECTIONS
except ImportError:
    COURSES = []
    ASSIGNMENTS = []
    NOTES = []
    CONCEPTS = []
    CONNECTIONS = []

log = logging.getLogger("knowledge")

router = APIRouter()


@router.post("/knowledge/build-context")
async def build_context(request: KnowledgeContextRequest):
    """
    Build a focused knowledge document for a specific topic and create a scoped K2 context.

    Entry points:
      1. Graph click:  { concept_id: "c330-cfg" }
      2. Free text:    { prompt: "study for my CFG exam" }
      3. Both:         { concept_id: "c330-cfg", prompt: "focus on parsing" }
    """
    query = request.prompt or ""
    course_filter = request.course_id

    if request.concept_id:
        concept = next((c for c in CONCEPTS if c["id"] == request.concept_id), None)
        if concept:
            query = f"{concept['label']} — {query}" if query else concept["label"]
            if not course_filter:
                course_filter = concept["course_id"]
        else:
            raise HTTPException(status_code=404, detail=f"Concept '{request.concept_id}' not found")

    if not query:
        raise HTTPException(status_code=400, detail="Provide either a 'prompt' or 'concept_id'")

    log.info(f"🧠 Building knowledge context for: \"{query}\" (course={course_filter})")

    try:
        prompt = build_topic_knowledge_prompt(
            query=query,
            concepts=CONCEPTS,
            assignments=ASSIGNMENTS,
            notes=NOTES,
            connections=CONNECTIONS,
            courses=COURSES,
            course_filter=course_filter,
        )
        context_doc = await k2_service.build_knowledge_document(prompt)
        log.info(f"📄 Generated knowledge doc ({len(context_doc)} chars)")

        agent_url = None
        if k2_service.ready:
            try:
                agent_name = f"Syllara: {query[:40]}"
                agent_url = await k2_service.create_topic_agent(agent_name, context_doc)
                log.info(f"✅ Agent created: {agent_url}")
                k2_service.store_agent_context(agent_url, context_doc)
            except Exception as e:
                log.warning(f"⚠️  Agent creation failed: {e}")

        return {
            "status": "success",
            "query": query,
            "course": course_filter,
            "agent_url": agent_url,
        }
    except Exception as e:
        log.error(f"❌ build-context failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/knowledge/refresh-from-graph")
async def refresh_from_graph(request: GraphRefreshRequest):
    """
    Analyze the knowledge graph and update the main K2 working context.
    """
    if not request.nodes:
        raise HTTPException(status_code=400, detail="Cannot refresh from empty graph")

    if not k2_service.ready:
        return {"status": "skipped", "reason": "K2 service disconnected"}

    try:
        prompt = build_graph_analysis_prompt(
            nodes=request.nodes,
            edges=request.edges,
            mastery=request.mastery,
        )
        context_doc = await k2_service.build_knowledge_document(prompt)
        log.info(f"📄 Graph knowledge doc ({len(context_doc)} chars)")

        await k2_service.update_agent_knowledge(context_doc)
        log.info("✅ Graph synced into K2 working memory")

        return {"status": "success", "message": "Graph successfully synced into K2"}
    except Exception as e:
        log.error(f"❌ refresh-from-graph failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/knowledge/recommend-courses")
async def recommend_courses(request: CourseRecommendationRequest):
    """
    Recommend 3 future courses using the same build-context flow:
      1. Use the local Rutgers-oriented mock catalog
      2. Build a knowledge doc via K2
      3. Create a scoped K2 agent context
      4. Extract 3 structured recommendations via K2 JSON generation
    """
    if not request.taken_course_ids:
        raise HTTPException(status_code=400, detail="taken_course_ids must not be empty")

    log.info(f"🎓 Recommending courses for taken={request.taken_course_ids}")

    try:
        catalog = [
            {
                "course_id": course["course_code"].replace(" ", ""),
                "name": course["name"],
                "credits": course.get("credits", 3),
                "description": f"Graduate-level Rutgers Computer Science offering in {course['name'].lower()}.",
            }
            for course in COURSES
        ]

        taken_upper = {cid.upper().replace(" ", "") for cid in request.taken_course_ids}
        taken_courses = [c for c in catalog if c.get("course_id", "").upper() in taken_upper]

        # 2. Build knowledge document
        prompt = build_course_recommendation_prompt(
            taken_courses=taken_courses,
            all_cmsc_courses=catalog,
        )
        context_doc = await k2_service.build_knowledge_document(prompt)
        log.info(f"📄 Generated course recommendation doc ({len(context_doc)} chars)")

        # 3. Create scoped K2 context
        agent_url = None
        if k2_service.ready:
            try:
                agent_name = "Syllara: Course Advisor"
                agent_url = await k2_service.create_topic_agent(agent_name, context_doc)
                log.info(f"✅ Course advisor agent created: {agent_url}")
                k2_service.store_agent_context(agent_url, context_doc)
            except Exception as e:
                log.warning(f"⚠️  Agent creation failed: {e}")

        # 4. Extract structured recommendations
        json_prompt = build_recommendation_json_prompt(context_doc, request.taken_course_ids)
        recommendations = await k2_service.generate_json(json_prompt)
        if isinstance(recommendations, list):
            recommendations = recommendations[:3]
        log.info(f"✅ Got {len(recommendations)} course recommendations")

        return {
            "status": "success",
            "agent_url": agent_url,
            "recommendations": recommendations,
        }
    except HTTPException:
        raise
    except Exception as e:
        log.error(f"❌ recommend-courses failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
