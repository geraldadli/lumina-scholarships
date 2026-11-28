# Release APK QA checklist

Run this on a real Android phone before an APK goes to the judges. Widget tests run in a fake
window with test fonts, so they cannot replace a check on a phone.

## 0. What you need

- An Android 8.0+ phone. For the on-device AI checks, a phone that supports Gemini Nano.
- A test account for email sign-in (ask the backend engineer, never put it in the repo).
- For the cloud AI test on Xiaomi, POCO or Redmi phones: someone with Remote Config access in the
  Firebase Console.
- For the log and AICore steps: the phone connected over USB with USB debugging on, and `adb`.
  `adb` comes with the Android SDK. If PowerShell says `adb` is not recognized, run this once in
  that window:

  ```powershell
  Set-Alias adb "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
  ```

  `adb devices` should then list the phone as `device`. If it says `unauthorized`, tap **Allow**
  on the phone.

## 1. Get and install the judge APK

Test the same `app-release.apk` file the judges will receive, installed the way they will
install it. Do not install with `flutter install` or `flutter run`: that builds and installs a
fresh copy, which may not be the file the judges get.

1. Download the `app-release.apk` that will be shared with the judges (the submission link).
2. Write down its SHA-256 for the report. On Windows:
   `certutil -hashfile app-release.apk SHA256`.
3. Copy the file to the phone: download it on the phone, or copy it to the phone's Download
   folder over USB (`adb push app-release.apk /sdcard/Download/app-release.apk`).
4. On the phone, open the **Files** app, open `app-release.apk`, allow installing from this
   source if Android asks, then tap **Install** (or **Update**) and **Open**.

The app id is `com.lumina.app`, the same as the Lumina AI Lab example app, so installing one
replaces the other. If Android says the app conflicts with an existing package, uninstall Lumina
from the phone and open the APK again.

### Building the judge APK

Only for the person who builds the file.

The judges install the APK outside Google Play, so App Check's Play Integrity check rejects it
and cloud AI shows "App not verified". The judge APK therefore uses an App Check **debug token**,
which the hackathon accepts in submissions:

1. Firebase Console > App Check > Apps > the Android app `com.lumina.app` > menu > **Manage debug
   tokens** > **Add debug token**. Name it (for example `judge-apk`), copy the value, save.
2. Put it in `_local/app_check.json` (the `_local/` folder is ignored by Git, never commit the
   token): `{"APP_CHECK_DEBUG_TOKEN": "the token"}`.
3. From the repository root:

```powershell
cd frontend
flutter pub get
flutter analyze
flutter test
flutter build apk --release --dart-define-from-file=../_local/app_check.json
```

The file is `frontend/build/app/outputs/flutter-apk/app-release.apk`. Share this file, and note
the commit it was built from. Anyone who has the APK can read the token out of it, so delete the
token in the Console when judging is over. Without `--dart-define-from-file` the release build
uses Play Integrity, which only works for an app installed from Google Play.

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

Check the label under each answer, not only that an answer appears: "Answered on this phone"
means Gemini Nano, "Answered with cloud AI" means cloud Gemini. Cloud AI is turned on and off in
**Profile > Privacy & AI > Allow cloud AI**. The same screen shows the on-device model status and
its name.

| Check | Pass when |
|---|---|
| Cloud AI off, phone with Gemini Nano | Answer shows "Answered on this phone" |
| Cloud AI off, phone with Gemini Nano 4 (see below) | Same, and the log shows `using=PREVIEW_FAST` |
| Cloud AI off, phone without Gemini Nano | Explains that on-device AI is unavailable and offers cloud AI |
| Cloud AI on, phone with Gemini Nano | Answer shows "Answered on this phone": Nano goes first |
| Cloud AI on, Gemini Nano not available | Answer shows "Answered with cloud AI" |

### Where each answer came from (log)

The app logs which model answered, without the question or the answer. Clear the log, ask a
question, then read it:

```powershell
adb logcat -c
```

```powershell
adb logcat -d -s LuminaHybridAi
```

| Log line | Meaning |
|---|---|
| `Gemini Nano model: requested=PREVIEW_FAST using=PREVIEW_FAST status=AVAILABLE` | Gemini Nano 4 Fast is ready on the phone |
| `Gemini Nano model: requested=PREVIEW_FAST using=STABLE ...` | No Gemini Nano 4 on the phone, the stable Nano is used |
| `ask selesai: ... nano=PREVIEW_FAST source=ON_DEVICE` | Answered by Gemini Nano 4 on the phone |
| `ask selesai: ... source=CLOUD` | Answered by cloud Gemini |

### Gemini Nano 4

Gemini Nano 4 is a preview model. A phone gets it only after this is turned on, and only if
AICore offers it for that phone:

1. Update **AICore** and **Private Compute Services** in the Play Store.
2. **Settings > Developer options > AICore** (or search Settings for `AICore`), turn on
   **Enable AICore Developer Preview**.
3. Keep the phone on Wi-Fi and charging until AICore has downloaded Gemini Nano 4 Fast
   (several GB).
4. Close Lumina from Recent apps and open it again, so it checks the model again.

Without these steps the app uses the phone's stable Gemini Nano. That is expected, not a failure.

### Testing cloud AI on a phone that has Gemini Nano

With cloud AI on, a phone with Gemini Nano still answers on the phone, so it does not test cloud
AI. Turn off AICore (the app that runs Gemini Nano) while testing:

```powershell
adb shell pm disable-user --user 0 com.google.android.aicore
```

```powershell
adb shell am force-stop com.lumina.app
```

Open Lumina, turn on cloud AI, ask a question and take a screenshot of the answer and its label.
Then turn AICore back on:

```powershell
adb shell pm enable com.google.android.aicore
```

Some phones refuse to turn off AICore (Xiaomi, POCO and Redmi with HyperOS answer `Cannot disable
system packages`). On those, send every question to the cloud with Remote Config for the test:

1. Firebase Console > Remote Config: set `ai_inference_mode` to `ONLY_IN_CLOUD` and publish.
2. Clear the app's data, so it fetches Remote Config again (you have to sign in again):
   `adb shell pm clear com.lumina.app`. HyperOS blocks that too; there, use **Settings > Apps >
   Manage apps > Lumina > Storage > Clear data** on the phone.
3. Sign in, turn on cloud AI, ask a question and take the screenshot. The log shows
   `mode=ONLY_IN_CLOUD ... source=CLOUD`.
4. Set `ai_inference_mode` back to `PREFER_ON_DEVICE`, publish, and clear the app's data again.
   Every phone with Lumina uses this value, so do not leave it on `ONLY_IN_CLOUD`.

If the answer is the card **App not verified** ("This app has not been verified to use cloud
AI"), App Check rejected the APK: it was built without the debug token (see "Building the judge
APK"), or the token was deleted in the Console. That is a failure of the judge APK, not of Ask AI.

## 5. Report

Write the results in `docs/qa/` (one file per QA round, named `YYYY-MM-DD-<what>.md`) and add the
phone to [device-matrix.md](device-matrix.md). Include the APK's SHA-256 and the commit it was
built from, and attach the screenshots of the "Answered on this phone" and "Answered with cloud
AI" labels to the pull request. Write **Pass** only for what you saw on the phone.
