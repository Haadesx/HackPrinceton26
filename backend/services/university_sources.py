"""Official university source adapters for catalog import and transcript matching."""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
import html
import re
from typing import Any

import httpx


PRINCETON_SCHEDULE_URL = "https://www.cs.princeton.edu/courses/schedule"
RUTGERS_SYNOPSES_URL = "https://www.cs.rutgers.edu/academics/graduate/m-s-program/course-synopses"


@dataclass(frozen=True)
class UniversitySource:
    slug: str
    name: str
    short_name: str
    official_domain: str
    homepage_url: str
    catalog_url: str | None
    color: str
    description: str
    location: str


DIRECTORY: dict[str, UniversitySource] = {
    "princeton": UniversitySource(
        slug="princeton",
        name="Princeton University",
        short_name="Princeton",
        official_domain="princeton.edu",
        homepage_url="https://www.princeton.edu/",
        catalog_url=PRINCETON_SCHEDULE_URL,
        color="#E77500",
        description="Official Princeton University homepage.",
        location="Princeton, NJ",
    ),
    "rutgers": UniversitySource(
        slug="rutgers",
        name="Rutgers University",
        short_name="Rutgers",
        official_domain="rutgers.edu",
        homepage_url="https://www.rutgers.edu/",
        catalog_url=RUTGERS_SYNOPSES_URL,
        color="#CC0033",
        description="Official Rutgers University homepage.",
        location="New Brunswick, NJ",
    ),
    "harvard": UniversitySource("harvard", "Harvard University", "Harvard", "harvard.edu", "https://www.harvard.edu/", None, "#A51C30", "Official Harvard University homepage.", "Cambridge, MA"),
    "yale": UniversitySource("yale", "Yale University", "Yale", "yale.edu", "https://www.yale.edu/", None, "#00356B", "Official Yale University homepage.", "New Haven, CT"),
    "columbia": UniversitySource("columbia", "Columbia University", "Columbia", "columbia.edu", "https://www.columbia.edu/", None, "#9BDDFF", "Official Columbia University homepage.", "New York, NY"),
    "upenn": UniversitySource("upenn", "University of Pennsylvania", "UPenn", "upenn.edu", "https://www.upenn.edu/", None, "#011F5B", "Official University of Pennsylvania homepage.", "Philadelphia, PA"),
    "cornell": UniversitySource("cornell", "Cornell University", "Cornell", "cornell.edu", "https://www.cornell.edu/", None, "#B31B1B", "Official Cornell University homepage.", "Ithaca, NY"),
    "brown": UniversitySource("brown", "Brown University", "Brown", "brown.edu", "https://www.brown.edu/", None, "#4E3629", "Official Brown University homepage.", "Providence, RI"),
    "dartmouth": UniversitySource("dartmouth", "Dartmouth College", "Dartmouth", "dartmouth.edu", "https://home.dartmouth.edu/", None, "#00693E", "Official Dartmouth homepage.", "Hanover, NH"),
    "mit": UniversitySource("mit", "Massachusetts Institute of Technology", "MIT", "mit.edu", "https://www.mit.edu/", None, "#A31F34", "Official MIT homepage.", "Cambridge, MA"),
    "stanford": UniversitySource("stanford", "Stanford University", "Stanford", "stanford.edu", "https://www.stanford.edu/", None, "#8C1515", "Official Stanford University homepage.", "Stanford, CA"),
    "cmu": UniversitySource("cmu", "Carnegie Mellon University", "CMU", "cmu.edu", "https://www.cmu.edu/", None, "#C41230", "Official Carnegie Mellon University homepage.", "Pittsburgh, PA"),
    "berkeley": UniversitySource("berkeley", "University of California, Berkeley", "UC Berkeley", "berkeley.edu", "https://www.berkeley.edu/", None, "#003262", "Official UC Berkeley homepage.", "Berkeley, CA"),
    "ucla": UniversitySource("ucla", "University of California, Los Angeles", "UCLA", "ucla.edu", "https://www.ucla.edu/", None, "#2774AE", "Official UCLA homepage.", "Los Angeles, CA"),
    "ucsd": UniversitySource("ucsd", "University of California San Diego", "UC San Diego", "ucsd.edu", "https://ucsd.edu/", None, "#006A96", "Official UC San Diego homepage.", "La Jolla, CA"),
    "umd": UniversitySource("umd", "University of Maryland", "UMD", "umd.edu", "https://www.umd.edu/", None, "#E21833", "Official University of Maryland homepage.", "College Park, MD"),
    "umich": UniversitySource("umich", "University of Michigan", "Michigan", "umich.edu", "https://umich.edu/", None, "#00274C", "Official University of Michigan homepage.", "Ann Arbor, MI"),
    "uiuc": UniversitySource("uiuc", "University of Illinois Urbana-Champaign", "UIUC", "illinois.edu", "https://illinois.edu/", None, "#FF5F05", "Official UIUC homepage.", "Champaign, IL"),
    "gatech": UniversitySource("gatech", "Georgia Institute of Technology", "Georgia Tech", "gatech.edu", "https://www.gatech.edu/", None, "#B3A369", "Official Georgia Tech homepage.", "Atlanta, GA"),
    "utexas": UniversitySource("utexas", "The University of Texas at Austin", "UT Austin", "utexas.edu", "https://www.utexas.edu/", None, "#BF5700", "Official UT Austin homepage.", "Austin, TX"),
    "uw": UniversitySource("uw", "University of Washington", "UW", "washington.edu", "https://www.washington.edu/", None, "#4B2E83", "Official University of Washington homepage.", "Seattle, WA"),
    "duke": UniversitySource("duke", "Duke University", "Duke", "duke.edu", "https://duke.edu/", None, "#012169", "Official Duke University homepage.", "Durham, NC"),
    "jhu": UniversitySource("jhu", "Johns Hopkins University", "Johns Hopkins", "jhu.edu", "https://www.jhu.edu/", None, "#002D72", "Official Johns Hopkins University homepage.", "Baltimore, MD"),
    "nyu": UniversitySource("nyu", "New York University", "NYU", "nyu.edu", "https://www.nyu.edu/", None, "#57068C", "Official New York University homepage.", "New York, NY"),
    "usc": UniversitySource("usc", "University of Southern California", "USC", "usc.edu", "https://www.usc.edu/", None, "#990000", "Official USC homepage.", "Los Angeles, CA"),
    "northeastern": UniversitySource("northeastern", "Northeastern University", "Northeastern", "northeastern.edu", "https://www.northeastern.edu/", None, "#C8102E", "Official Northeastern University homepage.", "Boston, MA"),
    "purdue": UniversitySource("purdue", "Purdue University", "Purdue", "purdue.edu", "https://www.purdue.edu/", None, "#CFB991", "Official Purdue University homepage.", "West Lafayette, IN"),
}

CATALOG_SOURCES = {"princeton", "rutgers"}


class UniversitySourcesService:
    def __init__(self) -> None:
        self._client = httpx.AsyncClient(timeout=25.0, follow_redirects=True, verify=False)

    async def close(self) -> None:
        await self._client.aclose()

    def search(self, query: str | None = None) -> list[dict[str, Any]]:
        needle = (query or "").strip().lower()
        results: list[dict[str, Any]] = []
        for source in DIRECTORY.values():
            haystack = " ".join(
                [source.slug, source.name, source.short_name, source.official_domain, source.location]
            ).lower()
            if needle and needle not in haystack:
                continue
            results.append(self._serialize_source(source))
        return sorted(results, key=lambda item: (needle not in item["name"].lower(), item["name"]))[:12]

    async def get_university_profile(self, slug: str) -> dict[str, Any]:
        source = self._get_source(slug)
        html_text = await self._fetch(source.homepage_url)
        title = self._extract_meta(html_text, "og:title") or self._extract_title(html_text) or source.name
        description = (
            self._extract_meta(html_text, "description")
            or self._extract_meta(html_text, "og:description")
            or source.description
        )
        return {
            "university": self._serialize_source(source),
            "homepage_title": title,
            "homepage_description": description,
        }

    async def get_catalog(self, slug: str) -> dict[str, Any]:
        source = self._get_source(slug)
        if not source.catalog_url:
            raise ValueError(f"Catalog import is not supported yet for '{source.name}'")
        html_text = await self._fetch(source.catalog_url)
        courses = self._parse_catalog(source, html_text)
        return {
            "university": self._serialize_source(source),
            "fetched_at": datetime.now(timezone.utc).isoformat(),
            "courses": courses,
        }

    async def import_transcript(self, slug: str, transcript_text: str, filename: str, pages: int) -> dict[str, Any]:
        source = self._get_source(slug)
        catalog = await self.get_catalog(slug)
        matched_courses = self._match_transcript_courses(source, transcript_text, catalog["courses"])
        return {
            "university": catalog["university"],
            "filename": filename,
            "pages": pages,
            "matched_courses": matched_courses,
            "match_count": len(matched_courses),
            "text_preview": transcript_text[:2500],
        }

    def _get_source(self, slug: str) -> UniversitySource:
        source = DIRECTORY.get(slug.lower())
        if not source:
            supported = ", ".join(sorted(DIRECTORY))
            raise ValueError(f"Unsupported university '{slug}'. Supported: {supported}")
        return source

    async def _fetch(self, url: str) -> str:
        response = await self._client.get(url, headers={"User-Agent": "Syllara/1.0"})
        response.raise_for_status()
        return response.text

    def _serialize_source(self, source: UniversitySource) -> dict[str, Any]:
        return {
            "slug": source.slug,
            "name": source.name,
            "short_name": source.short_name,
            "official_domain": source.official_domain,
            "homepage_url": source.homepage_url,
            "catalog_url": source.catalog_url,
            "color": source.color,
            "description": source.description,
            "location": source.location,
            "catalog_supported": source.slug in CATALOG_SOURCES,
            "transcript_supported": source.slug in CATALOG_SOURCES,
        }

    def _parse_catalog(self, source: UniversitySource, html_text: str) -> list[dict[str, Any]]:
        if source.slug == "princeton":
            return self._parse_princeton_catalog(html_text, source)
        if source.slug == "rutgers":
            return self._parse_rutgers_catalog(html_text, source)
        raise ValueError(f"No parser for {source.slug}")

    def _parse_princeton_catalog(self, html_text: str, source: UniversitySource) -> list[dict[str, Any]]:
        row_pattern = re.compile(
            r"<tr>\s*<td>\s*<a href=\"(?P<href>[^\"]+)\">\s*(?P<code>[A-Z]{3}\d+[A-Z]?)</a>\s*</td>\s*"
            r"<td>\s*(?P<title>.*?)\s*</td>\s*<td>\s*(?P<professors>.*?)\s*</td>\s*<td>\s*(?P<meeting>.*?)\s*</td>\s*</tr>",
            re.S,
        )
        courses: list[dict[str, Any]] = []
        for match in row_pattern.finditer(html_text):
            code = match.group("code").strip()
            title = self._clean_text(match.group("title"))
            professors = self._clean_text(match.group("professors")).replace(" , ", ", ")
            meeting = self._clean_text(match.group("meeting"))
            course_id = f"{source.slug}-{code.lower()}"
            courses.append(
                {
                    "id": course_id,
                    "course_code": code,
                    "name": title,
                    "instructor": professors or "Princeton CS Faculty",
                    "meeting_times": meeting or "See official schedule",
                    "catalog_url": f"https://www.cs.princeton.edu{match.group('href')}",
                    "official_source": source.catalog_url,
                    "official_domain": source.official_domain,
                    "university_slug": source.slug,
                    "credits": 3,
                }
            )
        return courses

    def _parse_rutgers_catalog(self, html_text: str, source: UniversitySource) -> list[dict[str, Any]]:
        block_pattern = re.compile(
            r'<div class="latestnews-item[^"]*catid-69[^"]*">.*?<a href="(?P<href>/academics/graduate/m-s-program/course-synopses/course-details/[^"]+)"[^>]*>'
            r'\s*<span>(?P<label>16:198:\d+\s*-\s*.*?)</span>\s*</a>.*?(?:<dd class="newsextra">(?P<meta>.*?)</dd>)?',
            re.S,
        )
        courses: list[dict[str, Any]] = []
        for match in block_pattern.finditer(html_text):
            label = self._clean_text(match.group("label"))
            if " - " not in label:
                continue
            code, title = [part.strip() for part in label.split(" - ", 1)]
            meta_raw = match.group("meta") or ""
            meta = [self._clean_text(part) for part in re.findall(r'<span class="detail_data">(.*?)</span>', meta_raw, re.S)]
            meeting = ", ".join(part for part in meta if part) or "See official synopsis"
            course_id = f"{source.slug}-{code.replace(':', '-').lower()}"
            courses.append(
                {
                    "id": course_id,
                    "course_code": code,
                    "name": title,
                    "instructor": "Rutgers CS Faculty",
                    "meeting_times": meeting,
                    "catalog_url": f"https://www.cs.rutgers.edu{match.group('href')}",
                    "official_source": source.catalog_url,
                    "official_domain": source.official_domain,
                    "university_slug": source.slug,
                    "credits": 3,
                }
            )
        return courses

    def _match_transcript_courses(
        self,
        source: UniversitySource,
        transcript_text: str,
        catalog_courses: list[dict[str, Any]],
    ) -> list[dict[str, Any]]:
        normalized_text = transcript_text.replace("\u00a0", " ")
        grade_pattern = re.compile(r"\b(A\+|A-|A|B\+|B-|B|C\+|C-|C|D\+|D|F|P|NP|S|U)\b")
        catalog_lookup = {self._normalize_code(course["course_code"]): course for course in catalog_courses}
        ordered_matches: list[dict[str, Any]] = []
        seen: set[str] = set()

        if source.slug == "princeton":
            code_pattern = re.compile(r"\b([A-Z]{3}\s?\d{3}[A-Z]?)\b")
        else:
            code_pattern = re.compile(r"\b((?:\d{2}:)?198:\d{3})\b")

        for line in normalized_text.splitlines():
            code_match = code_pattern.search(line.upper())
            if not code_match:
                continue
            raw_code = code_match.group(1)
            normalized_code = self._normalize_code(raw_code)
            course = catalog_lookup.get(normalized_code)
            if not course or normalized_code in seen:
                continue

            grade_match = grade_pattern.search(line.upper())
            imported = {
                **course,
                "grade": grade_match.group(1) if grade_match else None,
                "transcript_line": " ".join(line.split())[:220],
                "workflow_state": "completed",
                "progress": 100,
                "time_zone": "America/New_York",
            }
            ordered_matches.append(imported)
            seen.add(normalized_code)

        return ordered_matches

    def _normalize_code(self, code: str) -> str:
        return re.sub(r"[^A-Z0-9]", "", code.upper())

    def _clean_text(self, value: str) -> str:
        text = re.sub(r"<[^>]+>", " ", value)
        text = html.unescape(text)
        return " ".join(text.split())

    def _extract_meta(self, html_text: str, name: str) -> str | None:
        patterns = [
            rf'<meta[^>]+property="{re.escape(name)}"[^>]+content="([^"]+)"',
            rf'<meta[^>]+name="{re.escape(name)}"[^>]+content="([^"]+)"',
            rf'<meta[^>]+content="([^"]+)"[^>]+property="{re.escape(name)}"',
            rf'<meta[^>]+content="([^"]+)"[^>]+name="{re.escape(name)}"',
        ]
        for pattern in patterns:
            match = re.search(pattern, html_text, re.I)
            if match:
                return html.unescape(match.group(1)).strip()
        return None

    def _extract_title(self, html_text: str) -> str | None:
        match = re.search(r"<title>(.*?)</title>", html_text, re.I | re.S)
        if not match:
            return None
        return self._clean_text(match.group(1))


university_sources_service = UniversitySourcesService()
