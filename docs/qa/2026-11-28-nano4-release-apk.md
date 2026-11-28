# QA: Gemini Nano 4 release APK (2026-11-28)

The app now asks AICore for Gemini Nano 4 and falls back to the phone's stable Gemini Nano (see
`packages/hybrid_ai/README.md`, "Gemini Nano 4"). Checked with
[release-apk-checklist.md](release-apk-checklist.md).

## Build

| | |
|---|---|
| Commit | `fe7317c` (`main` at `cba15c4` + the Gemini Nano 4 change, first opened as PR #20 and moved into PR #19) |
| Build | `flutter build apk --release`, without the App Check debug token |
| APK SHA-256 | `11b9592dc407a288207dcdb6d540ef958a4a7da6a935b966d112745f36866274` |
| Install | `app-release.apk` opened from the phone's Files app, as the judges will |
| Phone | POCO F8 Pro, Android 16 (HyperOS 3), AICore Developer Preview on, Gemini Nano 4 Fast downloaded |

Retest build (judge APK, after the App Check fix):

| | |
|---|---|
| Commit | `0b7bb45` (PR #19, on top of `main` at `cba15c4`) |
| Build | `flutter build apk --release --dart-define-from-file=../_local/app_check.json` (App Check debug token) |
| APK SHA-256 | `a89791e46eb525f3ddff1b7d89efa3a4d27fcc44e31b3085e3369f628a6bd95b` |
| Install | `adb install -r` over USB (the same file; like the Files app, not from Google Play) |

## Automated checks

| Check | Result |
|---|---|
| `./gradlew :hybrid_ai:testDebugUnitTest` | 49 / 49 pass, 5 of them new for the Gemini Nano 4 choice and fallback |
| `:hybrid_ai:compileReleaseKotlin` | Pass |

## Phone results

| Check | Result |
|---|---|
| Email and Google sign-in, Forgot password | Pass |
| UI and UX: all tabs, Customize look, dark mode | Pass |
| Ask AI, cloud AI off, Gemini Nano 4 | Pass |
| Ask AI, cloud AI on (Nano available) | Answered on the phone, as designed |
| Ask AI, cloud only (Remote Config `ONLY_IN_CLOUD`) | **Fail:** "App not verified" |
| Same, judge APK built with the App Check debug token | **Pass:** "Answered with cloud AI" |

### Cloud AI

- HyperOS does not let `adb` turn off AICore (`Cannot disable system packages`) or clear app data,
  so cloud AI was forced with Remote Config `ai_inference_mode = ONLY_IN_CLOUD` and **Settings >
  Apps > Manage apps > Lumina > Storage > Clear data** (checklist, "Testing cloud AI on a phone
  that has Gemini Nano").
- With cloud AI on and Gemini Nano available, the answer said "Answered on this phone"
  (`mode=PREFER_ON_DEVICE ... source=ON_DEVICE`). That is the expected hybrid order, and it is why
  the 2026-11-27 round did not show cloud AI.
- Cloud only: the answer was the card **App not verified**. This APK was built with a plain
  `flutter build apk --release`, so App Check used Play Integrity, which rejects an APK installed
  outside Google Play. Every judge without Gemini Nano would have hit this.
- Fix: release builds use an App Check debug token when one is given at build time
  (`frontend/lib/main.dart`, "Building the judge APK" in the checklist). The hackathon accepts
  debug tokens in submissions.
- Retest with the judge APK built that way, still `ONLY_IN_CLOUD`: the answer said **"Answered
  with cloud AI"** (screenshot in PR #19), and the log showed
  `ask selesai: mode=ONLY_IN_CLOUD nano=STABLE source=CLOUD latencyMs=2249`.
- Afterwards `ai_inference_mode` went back to `PREFER_ON_DEVICE`.

Gemini Nano 4, from `adb logcat -s LuminaHybridAi`:

```
Gemini Nano status: outcome=REPORTED status=AVAILABLE -> AVAILABLE model=PREVIEW_FAST
Gemini Nano model: requested=PREVIEW_FAST using=PREVIEW_FAST status=AVAILABLE
ask selesai: mode=ONLY_ON_DEVICE nano=PREVIEW_FAST source=ON_DEVICE latencyMs=6800
ask selesai: mode=ONLY_ON_DEVICE nano=PREVIEW_FAST source=ON_DEVICE latencyMs=8327
```

## What this means for the judges

- A judge's phone uses Gemini Nano 4 only with the AICore Developer Preview turned on and Gemini
  Nano 4 downloaded. Otherwise it uses its stable Gemini Nano, or cloud AI when it has no Nano and
  cloud AI is on. [judge-apk.md](../judge-apk.md) explains this.
