# Release APK QA checklist

Run this on a real Android phone before an APK goes to the judges. Widget tests run in a fake
window with test fonts, so they cannot replace a check on a phone.

## 1. Build and install

From the repository root:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --release
flutter install -d DEVICE_ID
```

`DEVICE_ID` comes from `flutter devices`. The APK is at
`frontend/build/app/outputs/flutter-apk/app-release.apk`.

The app id is `com.lumina.app`, the same as the Lumina AI Lab example app, so installing one
replaces the other. If Android answers `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, uninstall Lumina
from the phone and install again.

## 2. Sign-in

| Check | Pass when |
|---|---|
| Email sign-in with the test account | Opens onboarding or Home |
| Forgot password, empty email | Asks to type the email first |
| Forgot password, typed email | Says a reset link is on its way |
| Continue with Google, then close the picker | Spinner stops, no error message |
| Continue with Google, finished | Signs in |

Google sign-in only works when the SHA-1 of the keystore that signed the APK is registered for
`com.lumina.app` in the Firebase Console. Release builds are signed with the debug keystore of
whoever built them, so a new builder needs their SHA-1 added.

## 3. UI and UX

| Check | Pass when |
|---|---|
| Home, Browse, Saved, Ask AI, Profile | Each tab opens, nothing is cut off |
| Scholarship details | Language requirements show one test per line |
| Profile > Customize look | Colour, text size, font, spacing, corners and contrast apply at once |
| Dark mode | Every tab is readable |
| Text size Extra large | No text overflows or overlaps |

## 4. Ask AI

| Check | Pass when |
|---|---|
| Cloud AI off, phone with Gemini Nano | Answers on the device |
| Cloud AI off, phone without Gemini Nano | Explains that on-device AI is unavailable and offers cloud AI |
| Cloud AI on | Answers through cloud Gemini |

Release builds use the Play Integrity provider for App Check (`frontend/lib/main.dart`). An APK
installed outside Google Play may fail it, and then cloud answers show "This app has not been
verified to use cloud AI". Record that result if it happens: it decides how the judge APK is
built.

## 5. Report

Write the results in `docs/qa/` (one file per QA round) and add the phone to
[device-matrix.md](device-matrix.md).
