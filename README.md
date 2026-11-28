# Lumina

Lumina is a free Android app in development that helps students find scholarships, understand eligibility requirements, and keep track of deadlines.

## What we're building

- Browse scholarships and filter by eligibility, field of study, and deadline.
- Check scholarship details against official sources.
- Save opportunities and track application progress.
- Ask an AI assistant to explain requirements or make a preparation checklist.

## How the AI works

The assistant runs on the phone first, through Firebase AI Logic hybrid inference and Android AICore:

1. **Gemini Nano 4** when the phone has it (AICore Developer Preview).
2. Otherwise the phone's **stable Gemini Nano**.
3. **Cloud Gemini** only when on-device AI is unavailable, the user allows cloud AI, and there is an internet connection.

Each answer is labelled "Answered on this phone" or "Answered with cloud AI". Details: [Hybrid AI package](packages/hybrid_ai/README.md).

## Tech stack

Flutter and Dart for the app, Kotlin for the Android AI integration, and Firebase: Authentication, Firestore (scholarship data and user data), Firebase AI Logic (Gemini Nano + cloud Gemini), App Check (a debug token for the judge APK and development builds, Play Integrity for Google Play builds) and Remote Config (AI mode and model choice).

Android package name: `com.lumina.app`.

## Repository structure

```
.
├── frontend/                 Flutter app (Android): browse, details, save, Ask AI
├── packages/hybrid_ai/       Hybrid AI bridge: Pigeon + Kotlin (Gemini Nano + cloud fallback)
├── backend/                  Node.js + TypeScript jobs (Firebase Admin SDK)
│   ├── data/                 scholarships.json, curated by the research team
│   ├── src/                  importer, source monitor, deadline processor
│   └── test/                 Firestore security rules tests (emulator)
├── docs/                     data contract and technical docs
├── .github/workflows/        CI and scheduled scholarship sync
├── firestore.rules           Firestore security rules
├── firestore.indexes.json    Firestore composite indexes
└── firebase.json             Firebase CLI / emulator config
```

## Docs

- [Firestore data contract](docs/firestore-contract.md): collections, fields, and Remote Config shared by app, AI, and backend
- [Flutter app](frontend/README.md): how to run it, demo mode, and which Firestore paths each screen uses
- [Hybrid AI package](packages/hybrid_ai/README.md): Dart API for Ask AI, checklist, and match score
- [Backend guide](backend/README.md): how scholarship data is imported, monitored, and synced
- [Installing the APK](docs/judge-apk.md): install the app on a phone and what to try
- [Release APK QA](docs/qa/release-apk-checklist.md): phone checks before an APK is shared, with the [device matrix](docs/qa/device-matrix.md) and one report per QA round in [docs/qa/](docs/qa/)
- [Contributing](CONTRIBUTING.md): branches, commit messages, and pull requests
