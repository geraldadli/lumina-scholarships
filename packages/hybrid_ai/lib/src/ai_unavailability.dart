/// The button/action the UI should offer when the AI is unavailable.
enum AiUnavailableAction {
  /// Send the user to the privacy settings so they can allow cloud AI.
  openPrivacySettings,

  /// Show a "Download AI model" button (call `HybridAi.downloadModel()`).
  downloadModel,

  /// Gemini Nano is downloading: show progress (from `HybridAi.downloadModel()`) and the text
  /// "wait for the download to finish". Offer "Try again" once the state is `completed`.
  waitForDownload,

  /// Show a "Try again" button.
  retry,

  /// Ask the user to change the question.
  editQuestion,

  /// Nothing the user can do; just show the explanation.
  none,
}

/// A single explanation for the "AI unavailable" state (the yellow box in the AI flow diagram).
///
/// The UI only needs to show [title], [message], and a button matching [action],
/// without knowing every error code. Get it from `HybridAiException.unavailability`.
class AiUnavailability {
  const AiUnavailability({required this.title, required this.message, required this.action});

  /// Short title, suitable for a card or dialog title.
  final String title;

  /// A friendly explanation in English.
  final String message;

  /// The suggested action for the user.
  final AiUnavailableAction action;

  @override
  String toString() => 'AiUnavailability($title, $action)';
}
