# QA: PR #18 release APK (2026-11-27)

PR #18 (`feat/app-web-ui`) reworks the app's UI: clearer layout, Customize look, dark mode and
page animations. Checked with [release-apk-checklist.md](release-apk-checklist.md).

## Build

| | |
|---|---|
| Commit | `4f0b792` |
| Flutter | 3.50.0 and 3.50.1 (stable) |
| Build | `flutter build apk --release` |
| Phone | POCO F8 Pro, Android 16, Gemini Nano supported |

## Automated checks

| Check | Result |
|---|---|
| `flutter analyze` | No issues |
| `flutter test` | 83 / 83 pass on Flutter 3.50.0 and 3.50.1 |
| `frontend/web/` in the PR diff | None |

## Rendering error in the auth tests

The team lead saw the Forgot password and Google-cancel tests fail with a rendering error. On
commit `e315923` the error only appeared in a window less than 48 px tall: the welcome screen
asked for a minimum height of (window height - 48), which is negative there and throws
"BoxConstraints has a negative minimum height". Commit `4f0b792` keeps that value at 0 or more
and adds a test with an empty and a 40 px tall window.

## Phone results

| Check | Result |
|---|---|
| Email sign-in with the test account | Pass |
| Forgot password | Pass |
| Google sign-in, picker closed | Pass |
| Google sign-in, finished | Pass |
| UI and UX: all tabs, Customize look, dark mode, Extra large text | Pass |
| Ask AI, cloud AI off (Gemini Nano) | Pass |
| Ask AI, cloud AI on | Not shown, see below |

Correction (2026-11-28): Ask AI answered with cloud AI on, but this phone has Gemini Nano, so
those answers were most likely made on the phone. The answer label was not recorded, so this
round does not show that cloud AI works, or that App Check (Play Integrity) accepts the APK.
The cloud AI check is in [2026-11-28-nano4-release-apk.md](2026-11-28-nano4-release-apk.md),
with every question sent to the cloud.

## Open

- Merge PR #18 with **Squash and merge**: an early commit on the branch still has `frontend/web/`.
