## Unreleased

- Gemini Nano 4: the on-device model is requested with `OnDeviceConfig(modelOption = ...)`, chosen by the new Remote Config key `on_device_model` (`PREVIEW_FAST` = Gemini Nano 4 Fast by default, `PREVIEW` = Gemini Nano 4 Full, `STABLE`). A preview model is used only when AICore already has it (AICore Developer Preview); otherwise the stable Nano is used, so phones without the preview keep on-device AI. The log line `Gemini Nano model: requested=... using=... status=...` and `ask selesai: ... nano=...` show which one ran. No pigeon contract change.
- Gemini Nano status no longer collapses three different situations into "not supported". `ModelAvailability` has a new last value `unknown` (pigeon contract change): it is returned when the on-device extension is missing or the status check fails (e.g. AICore cannot be reached). `unavailable` now means only that AICore itself reported UNAVAILABLE. Apps that `switch` over `ModelAvailability` must handle `unknown` (show "On-device AI is unavailable").
- The native log (tag `LuminaHybridAi`) now records which outcome happened: `outcome=EXTENSION_MISSING`, `outcome=CHECK_FAILED error=<type>: <message>`, or `outcome=REPORTED status=<status>`. No prompt, question or profile data is logged.
- New error code `ON_DEVICE_UNAVAILABLE` (`HybridAiErrorCode.onDeviceUnavailable`): private mode or `downloadModel()` with an unknown Nano state. Message "On-device AI is unavailable." with a "try again" action.

- `ContextGuard` accepts only `https://` source links. Firestore only holds https links (the backend importer enforces it), so a plain `http://` link is rejected with `NO_CONTEXT`.
- `ContextGuard` now parses the source link: a bare `https://`, an empty host, or an empty label (`.com`, `a..b`, `example.`) no longer counts as a source and is rejected with `NO_CONTEXT`.
- A timeout always wins over a network error, also when the timeout is wrapped in (or reported next to) a network error: the whole cause chain is checked. The message is now "AI took too long. Try again."
- Default cloud fallback model is now `gemini-3.5-flash-lite` (was `gemini-2.5-flash`). Remote Config `cloud_fallback_model` still overrides it when published.
- All user-facing text is now English: `userMessage`, the `AiUnavailability` title/message, `MatchReason.message`, checklist notes, native error messages, the public API docs, and the example app. The AI's answer language is still chosen with `languageCode` (`'en'` or `'id'`).
- New error code `TIMEOUT` (`HybridAiErrorCode.timeout`): a cloud request that takes too long (`RequestTimeoutException`, `SocketTimeoutException`, `DEADLINE_EXCEEDED`) is no longer reported as `NETWORK`. "No connection" and "timed out" now have separate messages.
- New action `AiUnavailableAction.waitForDownload` for `modelDownloading`: show download progress and offer "Coba lagi" once the download has completed.
- `ContextGuard`: `ask()` refuses to call any model when the scholarship has no title or no valid `https://` `sourceUrl`. New error code `NO_CONTEXT` (`HybridAiErrorCode.noContext`) with its own "AI unavailable" card.
- `HybridAiException.unavailability`: one `AiUnavailability` (title, message, suggested `AiUnavailableAction`) for the "AI unavailable" UI state.

## 0.1.0

- Pigeon contract `HybridAiHostApi` / `HybridAiFlutterApi`.
- Gemini Nano on-device with cloud fallback (`gemini-2.5-flash`) through Firebase AI Logic, controlled by Remote Config.
- Private mode (`allowCloud: false`) that forces on-device inference.
- Grounded prompts for Ask AI and a Prepare checklist with a rule-based fallback.
- `MatchScorer`: rule-based match score in Dart.
- Example app "Lumina AI Lab" for testing on a device.
