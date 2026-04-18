"""
Prompt template for generating structured markdown study guides.
"""


def build_study_guide_prompt(
    topic: str,
    course_id: str,
    course_name: str,
    course_topics: list[str],
    additional_context: str | None = None,
) -> str:
    """Build a prompt for generating a comprehensive study guide."""

    context_block = ""
    if additional_context:
        context_block = f"""
## Additional Context Provided by Student
{additional_context}
"""

    return f"""Create a comprehensive study guide for the following topic.

## Request Details
- **Topic**: {topic}
- **Course**: {course_id.upper()} — {course_name}
- **Course covers**: {', '.join(course_topics)}
{context_block}
## Output Requirements
Generate a well-structured markdown study guide that includes:

1. **Overview** — A brief 2-3 sentence introduction to the topic
2. **Key Concepts** — The most important ideas, each with a clear explanation
3. **Detailed Breakdown** — Deeper explanations with examples
   - For theory-heavy COS courses: include proof sketches or algorithm intuition
   - For ML/NLP courses: include modeling examples, ablation reasoning, or evaluation notes
   - For systems courses: include architecture or performance tradeoff examples
   - For methods courses: include study design, measurement, or causal reasoning examples
4. **Common Mistakes** — Pitfalls students typically encounter
5. **Practice Problems** — 3-5 practice questions with answers
6. **Connections** — How this topic relates to other topics in the course

Use proper markdown formatting with headers (##, ###), bold, lists, and code blocks where appropriate.
Make the guide thorough enough to study from, but concise enough to review in 15-20 minutes.
Write the guide itself, not commentary about the guide.
Do not mention being an AI, assistant, tutor, or model.
Do not include setup phrases like "here's a guide", "let's dive in", "I will walk through", or "to understand this topic".
Do not include hidden reasoning, analysis notes, or explanations addressed to yourself.
Address the student only through the content itself: definitions, explanations, examples, pitfalls, and practice.
Start directly with the first markdown heading.
"""
