"""Official university search, catalog import, and transcript matching routes."""

from fastapi import APIRouter, HTTPException, Query, UploadFile, File, Form

from services.parser import extract_text_from_pdf, extract_text_from_txt
from services.university_sources import university_sources_service


router = APIRouter()

ALLOWED_EXTENSIONS = {".pdf", ".txt", ".md", ".text"}
MAX_FILE_SIZE = 10 * 1024 * 1024


@router.get("/universities/search")
async def search_universities(q: str | None = Query(default=None)):
    return {"results": university_sources_service.search(q)}


@router.get("/universities/{slug}/catalog")
async def get_university_catalog(slug: str):
    try:
        return await university_sources_service.get_catalog(slug)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to load official catalog: {exc}")


@router.get("/universities/{slug}/profile")
async def get_university_profile(slug: str):
    try:
        return await university_sources_service.get_university_profile(slug)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Failed to load official university profile: {exc}")


@router.post("/transcript/import")
async def import_transcript(university_slug: str = Form(...), file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")

    ext = "." + file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type '{ext}'. Allowed: {', '.join(sorted(ALLOWED_EXTENSIONS))}",
        )

    content = await file.read()
    if len(content) > MAX_FILE_SIZE:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size is {MAX_FILE_SIZE // (1024 * 1024)} MB",
        )

    try:
        if ext == ".pdf":
            text, pages = extract_text_from_pdf(content)
        else:
            text = extract_text_from_txt(content)
            pages = 1

        if not text.strip():
            raise HTTPException(status_code=422, detail="No text content could be extracted from the file")

        return await university_sources_service.import_transcript(
            slug=university_slug,
            transcript_text=text,
            filename=file.filename,
            pages=pages,
        )
    except HTTPException:
        raise
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Failed to import transcript: {exc}")
