# Release APK QA checklist

Run this on a real Android phone before an APK goes to the judges. Widget tests run in a fake
window with test fonts, so they cannot replace a check on a phone.

## 1. Get and install the judge APK

Test the same `app-release.apk` file the judges will receive, installed the way they will
install it. Do not install with `flutter install` or `flutter run`: that builds and installs a
fresh copy, which may not be the file the judges get.

1. Download the `app-release.apk` that will be shared with the judges (the submission link).
2. Write down its SHA-256 for the report. On Windows:
   `certutil -hashfile app-release.apk SHA256`.
3. Copy the file to the phone (download it on the phone, or copy it to the phone's Download
   folder over USB).
4. On the phone, open the **Files** app, open `app-release.apk`, allow installing from this
   source if Android asks, then tap **Install** and **Open**.

The app id is `com.lumina.app`, the same as the Lumina AI Lab example app, so installing one
replaces the other. If Android says the app conflicts with an existing package, uninstall Lumina
from the phone and open the APK again.

### Building the judge APK

Only for the person who builds the file. From the repository root:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The file is `frontend/build/app/outputs/flutter-apk/app-release.apk`. Share this file, and note
the commit it was built from.

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
| Cloud AI off, phone with Gemini Nano | Answer shows "Answered on this phone" |
| Cloud AI off, phone without Gemini Nano | Explains that on-device AI is unavailable and offers cloud AI |
| Cloud AI on, Gemini Nano not available | Answer shows "Answered with cloud AI" |

Check the label under each answer, not only that an answer appears. With cloud AI on, a phone
with Gemini Nano still answers on the device, so it does not test cloud AI. To test cloud AI on
such a phone, turn off AICore (the app that runs Gemini Nano) while testing, with the phone
connected over USB:

```powershell
adb shell pm disable-user --user 0 com.google.android.aicore
```

Ask a question with cloud AI on, take a screenshot of the answer, then turn AICore back on:

```powershell
adb shell pm enable com.google.android.aicore
```

The app also logs where each answer came from, without the question or the answer:
`adb logcat -s LuminaHybridAi` shows `ask selesai: mode=PREFER_ON_DEVICE source=CLOUD` for a
cloud answer and `source=ON_DEVICE` for Gemini Nano.

Release builds use the Play Integrity provider for App Check (`frontend/lib/main.dart`). An APK
installed outside Google Play may fail it, and then cloud answers show "This app has not been
verified to use cloud AI". Record that result if it happens: it decides how the judge APK is
built.

## 5. Report

Write the results in `docs/qa/` (one file per QA round) and add the phone to
[device-matrix.md](device-matrix.md). Include the APK's SHA-256, and attach the screenshots of
the "Answered on this phone" and "Answered with cloud AI" labels to the pull request.
