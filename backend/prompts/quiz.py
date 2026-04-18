"""
Prompt template for generating multiple-choice quiz questions as structured JSON.
"""


def build_quiz_prompt(
    topic: str,
    course_id: str,
    course_name: str,
    course_topics: list[str],
    additional_context: str | None = None,
    count: int = 5,
) -> str:
    """Build a prompt for generating quiz questions."""

    context_block = ""
    if additional_context:
        context_block = f"""
## Additional Context Provided by Student
{additional_context}
"""

    return f"""Generate exactly {count} multiple-choice quiz questions for the following topic.

## Request Details
- **Topic**: {topic}
- **Course**: {course_id.upper()} — {course_name}
- **Course covers**: {', '.join(course_topics)}
{context_block}
## Output Format
Return a JSON object with a "questions" array. Each question has:
- "question": The question text (clear and unambiguous)
- "options": Array of exactly 4 answer choices (strings)
- "correct_index": Index of the correct answer (0-3)
- "explanation": Brief explanation of why the correct answer is right (1-2 sentences)

## Guidelines
- Questions should test understanding, not just memorization
- All 4 options should be plausible (no obviously wrong answers)
- Mix difficulty levels: 2 easy, 2 medium, 1 hard
- For theory-heavy COS courses: include proof intuition and reduction-style reasoning
- For ML/NLP courses: include modeling and evaluation choices
- For systems courses: include deployment and performance tradeoff questions
- For methods courses: include study-design and identification questions
- Each question must have exactly ONE correct answer
- Avoid "all of the above" or "none of the above" options

## Example Output Format
{{
  "questions": [
    {{
      "question": "Why might a variational approximation be preferred over exact posterior inference?",
      "options": [
        "It always produces the exact posterior more quickly",
        "It turns inference into an optimization problem that can be computed efficiently",
        "It avoids making any assumptions about the model",
        "It removes the need for probability distributions"
      ],
      "correct_index": 1,
      "explanation": "Variational inference uses optimization to approximate otherwise intractable posterior computations."
    }}
  ]
}}
"""
