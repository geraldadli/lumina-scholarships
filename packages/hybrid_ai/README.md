# hybrid_ai

Flutter plugin (Android only) for Lumina's AI assistant. It runs **Gemini Nano on the device** through Android AICore and falls back to a **cloud Gemini model** through Firebase AI Logic. The mode comes from Remote Config and the user's privacy setting.

```
Flutter (Dart)  ──Pigeon──▶  Kotlin: HybridAiApiImpl
  HybridAi                     ├─ InferencePolicy   Remote Config + privacy → inference mode
  MatchScorer (rule-based)     ├─ PromptBuilder     grounded prompt (scholarship data only)
                               ├─ ChecklistBuilder  official requirements + AI tips
                               └─ Firebase AI Logic (Gemini Nano ↔ gemini-2.5-flash)
```

## Usage

```yaml
# app/pubspec.yaml
dependencies:
  hybrid_ai:
    path: ../packages/hybrid_ai
```

```dart
import 'package:hybrid_ai/hybrid_ai.dart';

final ai = HybridAi();

// 1. Status: is Nano available, which mode is active, match threshold
final status = await ai.getStatus();
if (status.onDeviceModel == ModelAvailability.downloadable) {
  ai.downloadModel().listen((p) => print('${p.state} ${p.bytesDownloaded}/${p.totalBytes}'));
}

// 2. Match score (rule-based, offline)
final match = const MatchScorer().score(student, scholarship);
final isMatch = match.meetsThreshold(status.minMatchScore);

// 3. Ask AI (grounded in the scholarship data)
try {
  final answer = await ai.ask(AskRequest(
    question: 'Apa syarat bahasanya?',
    scholarship: scholarship,           // from scholarships/{id}
    student: student,                   // from users/{uid}, optional
    allowCloud: user.cloudAiAllowed,    // privacy.cloudAiAllowed
    languageCode: 'id',
  ));
  print('${answer.text} (${answer.source}, ${answer.latencyMs} ms)');
} on HybridAiException catch (e) {
  showError(e.userMessage); // friendly message; e.code drives the UI
}

// 4. Prepare checklist: never fails because of AI (falls back to source = rules)
final checklist = await ai.generateChecklist(ChecklistRequest(
  scholarship: scholarship, allowCloud: user.cloudAiAllowed, languageCode: 'id'));
```

## Behaviour

| Condition | Result |
|---|---|
| Remote Config `PREFER_ON_DEVICE` and Nano available | Answers on the device (`AiSource.onDevice`) |
| Nano not available or not downloaded, cloud allowed | Automatic fallback to the cloud (`AiSource.cloud`) |
| `allowCloud: false` (private mode) | Forced `ONLY_ON_DEVICE`; if Nano is not ready → `HybridAiException` |
| Checklist fails or AI is unavailable | Checklist from official requirements (`AiSource.rules`) |
| Scholarship has no title or no http(s) `sourceUrl` | `ask()` throws `noContext` before any model is called |

Privacy: prompts, questions, and profile data are never written to the log. The log records only the mode, source, and latency.

### Error codes (`HybridAiException.code`)

`noContext`, `privateModeUnavailable`, `onDeviceUnsupported`, `modelNotDownloaded`, `modelDownloading`, `busy`, `quotaExceeded`, `appCheckFailed`, `network`, `contentBlocked`, `emptyResponse`, `invalidRequest`, `firebaseNotConfigured`, `unknown`. Each one has a ready-to-show `userMessage` in Indonesian.

### "AI unavailable" state

Instead of switching over every code, show one state from `e.unavailability`:

```dart
} on HybridAiException catch (e) {
  final u = e.unavailability;          // title + message + suggested action
  showUnavailableCard(u.title, u.message);
  switch (u.action) {
    case AiUnavailableAction.openPrivacySettings: /* button: open Settings */
    case AiUnavailableAction.downloadModel:       /* button: ai.downloadModel() */
    case AiUnavailableAction.retry:               /* button: try again */
    case AiUnavailableAction.editQuestion:        /* focus the question field */
    case AiUnavailableAction.none:                /* explanation only */
  }
}
```

## Requirements for the host app

- Android `minSdk 26`, and `google-services.json` for `com.lumina.app` (never commit it).
- **App Check**: AI Logic is enforced. Debug builds must install `DebugAppCheckProviderFactory` and register the debug token in the Firebase Console (see `example/android/.../MainActivity.kt`).
- Gemini Nano only works on [supported devices](https://developers.google.com/ml-kit/genai) with a locked bootloader, and only while the app is in the foreground. Emulators can only test the cloud path.
- Gemini Nano is validated for English and Korean only, so check answer quality in Indonesian on a real device.

## Development

```bash
dart run pigeon --input pigeons/hybrid_ai.dart   # after changing the contract
flutter analyze && flutter test                 # Dart (MatchScorer, API, errors)
cd example/android && ./gradlew :hybrid_ai:testDebugUnitTest   # Kotlin (policy, prompt, checklist)
cd example && flutter run                        # test app "Lumina AI Lab" on a phone
```
