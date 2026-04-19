# Brain Brew iOS

Native SwiftUI iOS app for Brain Brew — academic mission control for Rutgers MSCS.

## Requirements

- macOS with Xcode 15+
- `xcodegen` (`brew install xcodegen`)
- Production API available at `https://api.brain-brew.us`

## Setup

```bash
# From this directory (hackprinceton/IOS_APP):
xcodegen generate
open BrainBrew.xcodeproj
```

Then in Xcode: select an iPhone simulator → Run.

## Default API

The iOS app now defaults to:

```text
https://api.brain-brew.us
```

That value is stored in:
- `project.yml`
- `Syllara/Resources/Info.plist`

## Local Development Override

If you want to point the app at a local backend instead, change `BrainBrewAPIBaseURL` in either:
- `project.yml` before regenerating the Xcode project
- or `Syllara/Resources/Info.plist`

Example local override:

```text
http://192.168.1.XXX:8000
```

The backend must also allow your device IP in CORS origins (`main.py`).

## Backend

Start the FastAPI backend before running the app locally:

```bash
cd ../backend
pip install -r requirements.txt
python run.py
```

## Voice Stack

- iOS always calls `POST /api/voice`
- Backend TTS priority is now:
  1. ElevenLabs
  2. Kokoro fallback
- Voice input still transcribes through `POST /api/transcribe`

## App Structure

```
Syllara/Sources/
  App/          SyllaraApp.swift, RootNavigationView.swift
  Core/         APIClient.swift, Models.swift, AudioManager.swift, VoiceRecorder.swift
  Components/   SyllaraColors.swift, SharedComponents.swift
  Features/
    Home/              Entry / splash screen
    CommandCenter/     Main dashboard — urgent assignments, course grid, announcements
    AssignmentDetail/  Risk score, knowledge gaps, recovery roadmap
    KnowledgeGraph/    Concept nodes and relationship browser
    StudyLab/          Quiz, flashcards, study guide generation + TTS playback
    Chat/              Semester-aware streaming chat + voice input + TTS
    Profile/           University search, profile view, transcript import
```

## Endpoints Used

| Feature | Endpoint |
|---------|----------|
| Health | `GET /api/health` |
| Courses | `GET /api/courses` |
| Assignments | `GET /api/assignments` |
| Announcements | `GET /api/announcements` |
| Concepts | `GET /api/concepts` |
| Connections | `GET /api/connections` |
| Chat (SSE stream) | `POST /api/chat` |
| Study guide | `POST /api/generate/study-guide` |
| Flashcards | `POST /api/generate/flashcards` |
| Quiz | `POST /api/generate/quiz` |
| TTS | `POST /api/voice` |
| STT | `POST /api/transcribe` |
| University search | `GET /api/universities/search?q=` |
| University profile | `GET /api/universities/{slug}/profile` |
| Transcript import | `POST /api/universities/{slug}/transcript/import` |

## Design

- Dark UI: `#111111` base, `#181818` cards
- Rutgers Scarlet: `#CC0033`
- Warm off-white text: `#F5F0E8`
- Monospaced labels for codes and metadata
