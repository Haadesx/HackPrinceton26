# BrainBrew iOS Handoff

This file summarizes the iOS-relevant changes made after the initial prompt to build the native app, so another Codex instance can continue from the current state without re-discovering context.

## Current Product Direction

- Product name: `BrainBrew`
- Public positioning is generalized for students
- Primary production backend target: `https://api.brain-brew.us`
- Web/frontend production domain target: `https://brain-brew.us`

## What Changed After The Initial iOS Prompt

### Branding

- The product name shifted from `Syllara` to `BrainBrew` in the visible app branding.
- The iOS Xcode project name is now `BrainBrew`.
- Some internal folder paths still use `Syllara/` as the source tree root. That is code-structure debt, not user-facing branding.
- Rutgers remains the current demo dataset, but not the public-facing headline.

### Backend Contract Changes That Matter To iOS

- Chat router was fixed to strip K2 scratchpad output instead of collapsing into a canned fallback.
- Production API is now intended to live at `https://api.brain-brew.us`.
- TTS provider order changed:
  1. ElevenLabs first
  2. Kokoro fallback
- STT remains backend-based via ElevenLabs transcription.
- Transcript import route is university-scoped:
  - `POST /api/universities/{slug}/transcript/import`

### iOS Changes Applied

- `APIClient.swift`
  - default base URL changed from local/LAN to `https://api.brain-brew.us`
  - transcript import path fixed to `POST /api/universities/{slug}/transcript/import`
- `project.yml`
  - `BrainBrewAPIBaseURL` changed to `https://api.brain-brew.us`
- `Syllara/Resources/Info.plist`
  - `BrainBrewAPIBaseURL` changed to `https://api.brain-brew.us`
- `README.md`
  - updated to reflect production-first API default
  - updated transcript import route
  - updated TTS stack description

## Current iOS Runtime Assumptions

- iOS app uses `BrainBrewAPIBaseURL` from Info.plist / project.yml
- Voice playback goes through `POST /api/voice`
- Pause/resume/stop is handled client-side by `AudioManager`
- Voice recording/transcription goes through `POST /api/transcribe`

## Production Validation Snapshot

Validated against `https://api.brain-brew.us` on `2026-04-19`.

- Working:
  - `GET /api/health`
  - `GET /api/courses`
  - `GET /api/announcements`
- Failing at deployed backend edge:
  - `POST /api/voice` -> `502`
  - `GET /api/universities/{slug}/profile` -> `502`
  - `GET /api/universities/{slug}/catalog` -> `502`
  - `POST /api/universities/{slug}/transcript/import` -> `404`
  - `POST /api/transcript/import` -> `502`

This means the current production blocker is backend deployment/runtime state, not the iOS base URL configuration.

## Known Follow-Up Work For Another Codex Instance

1. Rename remaining internal `Syllara` paths/types in the iOS source tree to `BrainBrew` for consistency.
2. Validate the generated `BrainBrew.xcodeproj` vs the leftover `Syllara.xcodeproj` and remove the stale duplicate if safe.
3. Test the iOS app against the deployed Render backend and production domains.
4. Confirm transcript import works against the live backend with the university-scoped route.
5. Confirm TTS playback works with ElevenLabs primary and Kokoro fallback under real production conditions.
6. Add release-oriented app polish:
   - loading states
   - network failure copy
   - production app icon/name audit
   - TestFlight/release build settings

## Recommended Next Validation Steps

1. Generate/open the Xcode project:
   - `cd IOS_APP`
   - `xcodegen generate`
   - `open BrainBrew.xcodeproj`
2. Run on simulator.
3. Test:
   - dashboard loads
   - chat works
   - transcript import works
   - read-aloud works
4. If local backend testing is needed, temporarily override `BrainBrewAPIBaseURL`.
