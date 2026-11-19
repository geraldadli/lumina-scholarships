## Unreleased

- `ContextGuard`: `ask()` refuses to call any model when the scholarship has no title or no http(s) `sourceUrl`. New error code `NO_CONTEXT` (`HybridAiErrorCode.noContext`) with its own "AI unavailable" card.
- `HybridAiException.unavailability`: one `AiUnavailability` (title, message, suggested `AiUnavailableAction`) for the "AI unavailable" UI state.

## 0.1.0

- Pigeon contract `HybridAiHostApi` / `HybridAiFlutterApi`.
- Gemini Nano on-device with cloud fallback (`gemini-2.5-flash`) through Firebase AI Logic, controlled by Remote Config.
- Private mode (`allowCloud: false`) that forces on-device inference.
- Grounded prompts for Ask AI and a Prepare checklist with a rule-based fallback.
- `MatchScorer`: rule-based match score in Dart.
- Example app "Lumina AI Lab" for testing on a device.
