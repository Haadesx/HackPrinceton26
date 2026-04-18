from fastapi import APIRouter, HTTPException, Query
from services.umd_service import umd_service
from typing import Optional, List

router = APIRouter()

@router.get("/umd/courses")
async def get_umd_courses(
    dept_id: Optional[str] = Query("CMSC", description="Department ID (e.g. CMSC)"),
    term: Optional[str] = Query(None, description="Term ID (e.g. 202601)")
):
    """Fetch courses from the UMD catalog."""
    courses = await umd_service.fetch_courses(dept_id=dept_id)
    return courses

@router.get("/umd/courses/{course_id}")
async def get_umd_course_details(course_id: str):
    """Fetch detailed information for a specific course."""
    details = await umd_service.fetch_course_details(course_id)
    if not details:
        raise HTTPException(status_code=404, detail="Course not found")
    return details

@router.get("/umd/courses/{course_id}/sections")
async def get_umd_course_sections(course_id: str):
    """Fetch all sections for a specific course."""
    sections = await umd_service.fetch_sections(course_id)
    return sections

@router.get("/umd/departments")
async def get_umd_departments():
    """Fetch the list of all UMD departments."""
    depts = await umd_service.fetch_departments()
    return depts

@router.get("/umd/terms")
async def get_umd_terms():
    """Fetch the list of all academic terms."""
    terms = await umd_service.fetch_terms()
    return terms
