# Syllara: Rutgers-First Academic Mission Control

## Team
- Varesh Patel
- Aparajita Sarkar
- Sinchana S Arun

## Product
Syllara is a Rutgers-first academic operating layer built for HackPrinceton 2026. It is not a generic chatbot and not a campus dashboard clone. It is a reasoning-first decision desk that helps students answer one question quickly: **what deserves my attention right now, and why?**

Instead of acting like a passive assistant, Syllara pulls together courses, deadlines, notes, and concept relationships into a single workspace that can:
- identify academic risk before a deadline slips
- explain *why* an assignment matters in the context of the rest of the semester
- generate focused study artifacts from the exact topic a student is struggling with
- surface cross-course connections so students learn faster, not just harder

## Why K2 Think V2
K2 Think V2 is the core reasoning layer behind Syllara. We use it for:
- multi-step chat responses grounded in the student dashboard state
- study guide, flashcard, and quiz generation
- concept extraction into the knowledge graph
- building scoped topic contexts for deep-dive conversations

This makes K2 central to the product rather than a bolt-on API call.

## What Makes It Ours
Syllara was rebuilt around Rutgers graduate CS workflows and then generalized outward so the platform can ingest other universities through official sources. We took inspiration from academic planning tools, but the current product is positioned as a ground-up reasoning workspace:
- the command center prioritizes what is urgent
- the graph shows what concepts unlock other concepts
- the study lab turns weak areas into actionable drills
- the assistant reasons over the whole academic situation, not just the latest prompt

## Credits
Built by Varesh Patel, Aparajita Sarkar, and Sinchana S Arun for HackPrinceton 2026.

## Best Track Fit
- Required track: `Education`
- Donor track: `Best Use of K2 Think V2`
- Optional extra angle: `Business and Enterprise` if you pitch it as a workflow OS for advising teams, tutors, or academic support centers

## Local Setup
### Backend
Create `backend/.env` with:

```env
K2_API_KEY=your_k2_key_here
K2_MODEL=MBZUAI-IFM/K2-Think-v2
```

Then run:

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

## Demo Pitch
“Syllara is an academic mission-control system for Rutgers students drowning in fragmented tools. K2 Think V2 acts as the reasoning engine, turning raw course data into prioritized action, explainable risk, and personalized study outputs, then scaling that workflow to other universities through official data sources.”
