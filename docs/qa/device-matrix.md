# Device test matrix

Phones the release APK has been checked on. Add a row for every phone after a QA round with
[release-apk-checklist.md](release-apk-checklist.md).

| Phone | Android | Gemini Nano | Sign-in | UI / UX | Ask AI, cloud off | Ask AI, cloud on | Date | Report |
|---|---|---|---|---|---|---|---|---|
| POCO F8 Pro | 16 | Gemini Nano 4 Fast (Developer Preview) | Pass | Pass | Pass | Pass with the debug token (fails without it) | 2026-11-28 | [Gemini Nano 4](2026-11-28-nano4-release-apk.md) |
| POCO F8 Pro | 16 | Gemini Nano 2 | Pass | Pass | Pass | Not shown | 2026-11-27 | [PR #18](2026-11-27-pr18-release-apk.md) |
| Team lead's phone | | | | | | Pending | | |

## What the AI columns mean

- **Gemini Nano:** the on-device model the phone used (Profile > Privacy & AI shows its name), or
  unavailable.
- **Ask AI, cloud off:** only Gemini Nano may answer. A phone without Nano should explain that
  on-device AI is unavailable and offer cloud AI.
- **Ask AI, cloud on:** an answer labelled "Answered with cloud AI" (cloud Gemini through Firebase
  AI Logic, which needs App Check to accept the APK). A phone with Nano answers on the phone even
  with cloud AI on, so turn AICore off or send every question to the cloud with Remote Config
  first: see the checklist, "Testing cloud AI on a phone that has Gemini Nano".
