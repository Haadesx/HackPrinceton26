import httpx
import logging
import asyncio
from typing import List, Dict, Any

log = logging.getLogger("umd_service")

UMD_API_BASE = "https://api.umd.io/v1"

class UMDService:
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=30.0)

    async def fetch_courses(self, dept_id: str = "CMSC") -> List[Dict[str, Any]]:
        """Fetch courses for a specific department."""
        try:
            log.info(f"Fetching courses for department: {dept_id}")
            resp = await self.client.get(f"{UMD_API_BASE}/courses", params={"dept_id": dept_id})
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Failed to fetch courses: {e}")
            return []

    async def fetch_course_details(self, course_id: str) -> Dict[str, Any]:
        """Fetch detailed information for a single course, including relationships."""
        try:
            resp = await self.client.get(f"{UMD_API_BASE}/courses/{course_id}")
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Failed to fetch course details for {course_id}: {e}")
            return {}

    async def fetch_sections(self, course_id: str) -> List[Dict[str, Any]]:
        """Fetch all sections for a specific course."""
        try:
            resp = await self.client.get(f"{UMD_API_BASE}/courses/{course_id}/sections")
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Failed to fetch sections for {course_id}: {e}")
            return []

    async def fetch_departments(self) -> List[Dict[str, Any]]:
        """Fetch the list of all UMD departments."""
        try:
            resp = await self.client.get(f"{UMD_API_BASE}/departments")
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Failed to fetch departments: {e}")
            return []

    async def fetch_terms(self) -> List[Dict[str, Any]]:
        """Fetch the list of all academic terms/semesters."""
        try:
            resp = await self.client.get(f"{UMD_API_BASE}/terms")
            resp.raise_for_status()
            return resp.json()
        except Exception as e:
            log.error(f"Failed to fetch terms: {e}")
            return []

    async def fetch_all_courses(self, dept_id: str = "CMSC") -> List[Dict[str, Any]]:
        """Fetch ALL courses for a department, paginating through the UMD API."""
        all_courses: List[Dict[str, Any]] = []
        page = 1
        per_page = 100
        try:
            while True:
                log.info(f"Fetching {dept_id} courses page {page} (per_page={per_page})")
                resp = await self.client.get(
                    f"{UMD_API_BASE}/courses",
                    params={"dept_id": dept_id, "per_page": per_page, "page": page},
                )
                resp.raise_for_status()
                batch = resp.json()
                all_courses.extend(batch)
                if len(batch) < per_page:
                    break
                page += 1
            log.info(f"Fetched {len(all_courses)} total {dept_id} courses")
        except Exception as e:
            log.error(f"Failed to fetch all courses for {dept_id}: {e}")
        return all_courses

    async def get_all_cmsc_prereqs(self) -> Dict[str, str]:
        """
        Helper to build a mapping of COURSE_ID -> PREREQ_STRING
        Specific to CMSC for the demo.
        """
        courses = await self.fetch_courses("CMSC")
        prereq_map = {}
        for c in courses:
            # The relationships field contains prereqs
            rel = c.get("relationships", {})
            prereqs = rel.get("prereqs")
            if prereqs:
                prereq_map[c["course_id"]] = prereqs
        return prereq_map

    async def close(self):
        await self.client.aclose()

umd_service = UMDService()
