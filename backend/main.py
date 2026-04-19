"""BrainBrew API application."""

from contextlib import asynccontextmanager
import logging

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
log = logging.getLogger("main")

from routers import chat, generate, parse, graph, data, knowledge, universities
from services.k2 import k2_service
from services.university_sources import university_sources_service


async def _init_ai():
    """Initialize the primary and fallback AI services at startup."""
    try:
        await k2_service.start()
        if k2_service.ready:
            log.info("K2 service ready")
        else:
            log.warning("K2 service not ready. Set K2_API_KEY in backend/.env.")
        if k2_service.gemini_fallback_ready:
            log.info("Gemini fallback ready")
        else:
            log.info("Gemini fallback not configured")
    except Exception as e:
        log.error(f"K2 init failed: {e}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    await _init_ai()
    yield
    log.info("Shutting down K2 service...")
    await k2_service.stop()
    await university_sources_service.close()


app = FastAPI(title="BrainBrew API", lifespan=lifespan)


def _cors_origins() -> list[str]:
    raw = os.getenv("CORS_ORIGINS", "").strip()
    if raw:
        return [origin.strip() for origin in raw.split(",") if origin.strip()]
    return [
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "https://brain-brew.us",
        "https://www.brain-brew.us",
    ]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Person 4: Voice / ElevenLabs
try:
    from routers import voice
    app.include_router(voice.router, prefix="/api")
except ImportError:
    log.warning("⚠️  Voice router not found — Person 4 hasn't pushed yet. Skipping.")

# Person 2: AI-powered routes
app.include_router(chat.router, prefix="/api")
app.include_router(generate.router, prefix="/api")
app.include_router(parse.router, prefix="/api")
app.include_router(graph.router, prefix="/api")
app.include_router(data.router, prefix="/api")
app.include_router(knowledge.router, prefix="/api")
app.include_router(universities.router, prefix="/api")

# Person 4: Mastery endpoint
try:
    from routers import mastery
    app.include_router(mastery.router, prefix="/api")
except ImportError:
    log.warning("⚠️  Mastery router not found — Person 4 hasn't pushed yet. Skipping.")


@app.get("/api/health")
def health():
    return {
        "status": "ok",
        "k2_ready": k2_service.ready,
        "gemini_fallback_ready": k2_service.gemini_fallback_ready,
    }
