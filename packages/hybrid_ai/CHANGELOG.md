## Unreleased

- All user-facing text is now English: `userMessage`, the `AiUnavailability` title/message, `MatchReason.message`, checklist notes, native error messages, the public API docs, and the example app. The AI's answer language is still chosen with `languageCode` (`'en'` or `'id'`).
- New error code `TIMEOUT` (`HybridAiErrorCode.timeout`): a cloud request that takes too long (`RequestTimeoutException`, `SocketTimeoutException`, `DEADLINE_EXCEEDED`) is no longer reported as `NETWORK`. "No connection" and "timed out" now have separate messages.
- New action `AiUnavailableAction.waitForDownload` for `modelDownloading`: show download progress and offer "Coba lagi" once the download has completed.
- `ContextGuard`: `ask()` refuses to call any model when the scholarship has no title or no http(s) `sourceUrl`. New error code `NO_CONTEXT` (`HybridAiErrorCode.noContext`) with its own "AI unavailable" card.
- `HybridAiException.unavailability`: one `AiUnavailability` (title, message, suggested `AiUnavailableAction`) for the "AI unavailable" UI state.

## 0.1.0

- Pigeon contract `HybridAiHostApi` / `HybridAiFlutterApi`.
- Gemini Nano on-device with cloud fallback (`gemini-2.5-flash`) through Firebase AI Logic, controlled by Remote Config.
- Private mode (`allowCloud: false`) that forces on-device inference.
- Grounded prompts for Ask AI and a Prepare checklist with a rule-based fallback.
- `MatchScorer`: rule-based match score in Dart.
- Example app "Lumina AI Lab" for testing on a device.
