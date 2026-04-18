"""
Context Builder Prompt
======================
This module builds structured prompts from raw mock data so the model can
reason over the student's semester context.

This document is what gives Syllara its live semester memory.
"""


def build_knowledge_document_prompt(
    courses: list[dict],
    assignments: list[dict],
    notes: list[dict],
) -> str:
    """
    Build a prompt that generates a comprehensive knowledge document
    from the student's raw course data.
    """

    courses_raw = "\n".join(
        f"- {c['id'].upper()}: {c['name']} | Topics: {', '.join(c.get('topics', []))}"
        for c in courses
    ) or "No courses found."

    assignments_raw = "\n".join(
        f"- [{a['course_id'].upper()}] {a['title']} | Due: {a['due_date']} | Type: {a['type']}"
        for a in sorted(assignments, key=lambda x: x.get("due_date", ""))
    ) or "No assignments found."

    notes_raw = "\n\n".join(
        f"=== {n['title']} ({n['course_id'].upper()}) ===\n{n['content'][:500]}"
        for n in notes
    ) or "No notes available."

    return f"""You are creating a knowledge document for an AI study assistant.
This document will be uploaded as a knowledge source to an AI agent that helps a Rutgers CS master's student.
Write a comprehensive, well-structured document that the agent can reference when answering questions.

## Raw Student Data

### Enrolled Courses
{courses_raw}

### Assignments & Deadlines
{assignments_raw}

### Lecture Notes (excerpts)
{notes_raw}

## Your Task
Transform the above raw data into a clear, comprehensive knowledge document with these sections:

1. **Student Profile** — Brief summary: what semester, which courses, general load
2. **Course Overviews** — For each course: name, key topics, what stage of semester (early/mid/late based on assignments)
3. **Upcoming Deadlines** — Sorted by urgency, include type (exam, project, homework)
4. **Key Concepts by Course** — The main academic concepts from the lecture notes, organized by course
5. **Study Priorities** — Based on deadlines and note content, what should the student focus on RIGHT NOW
6. **Cross-Course Connections** — Any concepts that appear in multiple courses (e.g., linear algebra in both MATH and CS)

Write this as a knowledge document, not a chat response.
Be specific, use the actual course/assignment names from the data.
This will be the primary reference for an AI that helps this specific student study."""


def build_chat_prompt(
    user_question: str,
    context_block: str | None = None,
    conversation_history: list[dict] | None = None,
    triage_statuses: dict[str, str] | None = None,
    system_status: dict[str, str] | None = None,
    active_remediation: dict | None = None,
    upcoming_deadlines: list[dict] | None = None,
    graph_context: list[dict] | None = None,
    graph_connections: list[dict] | None = None,
) -> str:
    """
    Build the final prompt string to send to the reasoning model for a chat request.

    If context_block is provided, it's included as a prefix.
    """
    parts = []

    if context_block:
        parts.append(f"[CONTEXT UPDATE]\n{context_block}\n[END CONTEXT]\n")
        
    dashboard_state = []
    if triage_statuses:
        criticals = [c for c, stat in triage_statuses.items() if stat == 'danger']
        if criticals:
            dashboard_state.append(f"At-risk assignments: {', '.join(criticals)} - danger")
    if active_remediation:
        dashboard_state.append(f"Active remediation: {active_remediation.get('topic', 'Unknown')}")
    if upcoming_deadlines:
        deadline_lines = []
        for d in upcoming_deadlines:
            days = d.get("days_left", "?")
            title = d.get("title", "Unknown")
            course = d.get("course_code", d.get("course_id", ""))
            cat = d.get("category", "")
            triage = d.get("triage")
            status = d.get("status", "")
            flag = " ⚠ AT RISK" if triage == "danger" else (" ✓ submitted" if status == "submitted" or triage == "submitted" else "")
            when = "overdue" if isinstance(days, (int, float)) and days < 0 else f"{days}d"
            deadline_lines.append(f"  [{course}] {title} ({cat}, {when}){flag}")
        dashboard_state.append("Upcoming assignments/exams:\n" + "\n".join(deadline_lines))
        
    if graph_context:
        # Group concepts by course, sort within each course by mastery ascending
        from collections import defaultdict
        by_course: dict[str, list[dict]] = defaultdict(list)
        for c in graph_context:
            by_course[c.get("course_id", "unknown")].append(c)

        graph_lines = []
        for course_id, concepts in sorted(by_course.items()):
            concepts_sorted = sorted(concepts, key=lambda x: x.get("mastery", 0))
            items = ", ".join(
                f"{c['label']}({c.get('mastery', 0)}%)" for c in concepts_sorted
            )
            graph_lines.append(f"  {course_id.upper()}: {items}")

        # Highlight weak spots (mastery < 50)
        weak = [c for c in graph_context if c.get("mastery", 100) < 50]
        weak_sorted = sorted(weak, key=lambda x: x.get("mastery", 0))
        if weak_sorted:
            weak_str = ", ".join(
                f"{c['label']} ({c['course_id'].upper()}, {c.get('mastery',0)}%)"
                for c in weak_sorted[:6]
            )
            dashboard_state.append(f"Low mastery concepts: {weak_str}")

        dashboard_state.append("Knowledge graph mastery by course:\n" + "\n".join(graph_lines))

    if graph_connections:
        cross = [c for c in graph_connections if c.get("cross_course")]
        intra = [c for c in graph_connections if not c.get("cross_course")]
        conn_lines = []
        if cross:
            conn_lines.append("  Cross-course links:")
            for c in cross:
                conn_lines.append(
                    f"    {c['source_label']} ({c['source_course'].upper()}) "
                    f"→ [{c['relationship']}] → "
                    f"{c['target_label']} ({c['target_course'].upper()})"
                )
        if intra:
            conn_lines.append("  Within-course links:")
            for c in intra:
                conn_lines.append(
                    f"    {c['source_label']} → [{c['relationship']}] → {c['target_label']} ({c['source_course'].upper()})"
                )
        dashboard_state.append("Concept relationships:\n" + "\n".join(conn_lines))

    if dashboard_state:
        parts.append("[STUDENT DASHBOARD STATE]\n" + "\n".join(dashboard_state) + "\n[END STATE]\n")

    # Add conversation history for multi-turn context (last 4 exchanges)
    if conversation_history:
        history_lines = []
        for msg in conversation_history[-8:]:  # last 4 turns (user + assistant)
            role = "Student" if msg.get("role") == "user" else "Syllara"
            history_lines.append(f"{role}: {msg.get('content', '')}")
        if history_lines:
            parts.append("Previous conversation:\n" + "\n".join(history_lines) + "\n")

    parts.append(f"Student question: {user_question}")

    return "\n\n".join(parts)


def build_study_guide_generation_prompt(
    topic: str,
    course_id: str,
    course_name: str,
    additional_context: str | None = None,
) -> str:
    """Build a prompt for the reasoning model to generate a study guide."""
    context = f"\nAdditional context: {additional_context}" if additional_context else ""
    return (
        f"Generate a comprehensive STUDY GUIDE for: {topic}\n"
        f"Course: {course_id.upper()} — {course_name}{context}\n\n"
        "Write directly to the student as a clean study resource, not as an assistant explaining what it is doing.\n"
        "Do not include any meta-commentary, planning notes, self-reference, or phrases like "
        "'here is a study guide', 'let's break this down', 'I will explain', or 'you should understand'.\n"
        "Do not talk about the prompt, the task, or your reasoning process.\n"
        "Start immediately with the study content in well-structured markdown.\n"
        "Use this structure: Overview, Key Concepts, Detailed Explanation with examples, "
        "Common Mistakes, Practice Problems with answers, and Connections to other topics.\n"
        "Keep the tone clear, student-facing, and easy to review before an exam."
    )


def build_flashcards_generation_prompt(
    topic: str,
    course_id: str,
    course_name: str,
    count: int = 10,
    additional_context: str | None = None,
) -> str:
    """Build a prompt for the reasoning model to generate JSON flashcards."""
    context = f"\nAdditional context: {additional_context}" if additional_context else ""
    return (
        f"Generate exactly {count} FLASHCARDS for: {topic}\n"
        f"Course: {course_id.upper()} — {course_name}{context}\n\n"
        f'Return ONLY a JSON object in this exact format:\n'
        f'{{"cards": [{{"front": "question", "back": "answer", "course_id": "{course_id}"}}]}}\n'
        "No markdown, no explanation, just the JSON object. "
        "Use the course knowledge base to ensure accuracy."
    )


def build_quiz_generation_prompt(
    topic: str,
    course_id: str,
    course_name: str,
    count: int = 5,
    additional_context: str | None = None,
) -> str:
    """Build a prompt for the reasoning model to generate JSON quiz questions."""
    context = f"\nAdditional context: {additional_context}" if additional_context else ""
    return (
        f"Generate exactly {count} multiple-choice QUIZ QUESTIONS for: {topic}\n"
        f"Course: {course_id.upper()} — {course_name}{context}\n\n"
        f'Return ONLY a JSON object in this exact format:\n'
        f'{{"questions": [{{"question": "...", "options": ["A", "B", "C", "D"], '
        f'"correct_index": 0, "explanation": "..."}}]}}\n'
        "No markdown, no explanation, just the JSON object. 4 options each, one correct answer."
    )


def build_concept_extract_prompt(
    text: str,
    course_id: str,
    course_name: str,
) -> str:
    """Build a prompt for the reasoning model to extract knowledge graph concepts from text."""
    truncated = text[:2500] + ("..." if len(text) > 2500 else "")
    return (
        f"Extract key academic CONCEPTS and their relationships from this text for a knowledge graph.\n"
        f"Course: {course_id.upper()} — {course_name}\n\n"
        f"Text to analyze:\n{truncated}\n\n"
        f'Return ONLY a JSON object:\n'
        f'{{"nodes": [{{"id": "snake_case_id", "label": "Human Label", '
        f'"course_id": "{course_id}", "description": "1-2 sentence explanation"}}], '
        f'"edges": [{{"source": "id1", "target": "id2", "relationship": "verb phrase"}}]}}\n'
        "Extract 5-15 concepts. No markdown, just the JSON."
    )
