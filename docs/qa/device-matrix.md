# Device test matrix

Phones the release APK has been checked on. Add a row for every phone after a QA round with
[release-apk-checklist.md](release-apk-checklist.md).

| Phone | Android | Gemini Nano | Sign-in | UI / UX | Ask AI, cloud off | Ask AI, cloud on | Date | Report |
|---|---|---|---|---|---|---|---|---|
| POCO F8 Pro | 16 | Supported | Pass | Pass | Pass | Pass | 2026-11-27 | [PR #18](2026-11-27-pr18-release-apk.md) |
| Team lead's phone | | | | | | Pending | | |

## What the AI columns mean

- **Gemini Nano:** what the app reports for on-device AI: supported, downloading, or unavailable.
- **Ask AI, cloud off:** only Gemini Nano may answer. A phone without Nano should explain that
  on-device AI is unavailable and offer cloud AI.
- **Ask AI, cloud on:** cloud Gemini through Firebase AI Logic, which needs App Check to accept
  the APK.
