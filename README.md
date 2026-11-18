# Lumina

Lumina is a free Android app in development that helps students find scholarships, understand eligibility requirements, and keep track of deadlines.

## What we're building

- Browse scholarships and filter by eligibility, field of study, and deadline.
- Check scholarship details against official sources.
- Save opportunities and track application progress.
- Ask an AI assistant to explain requirements or make a preparation checklist.

## How the AI works

The assistant is designed to use Gemini Nano on supported Android devices. When Nano is unavailable, it can use cloud Gemini through Firebase AI Logic if the user allows cloud processing and has an internet connection.

## Tech stack

Flutter and Dart for the app, Kotlin for the Android AI integration, and Firebase for authentication, scholarship data, and hybrid AI.

Android package name: `com.lumina.app`.

## Repository structure

```
.
├── app/                      Flutter app + Kotlin/Pigeon hybrid AI bridge (coming soon)
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
- [Backend guide](backend/README.md): how scholarship data is imported, monitored, and synced
- [Contributing](CONTRIBUTING.md): branches, commit messages, and pull requests
