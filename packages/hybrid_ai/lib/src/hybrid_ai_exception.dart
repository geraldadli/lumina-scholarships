import 'package:flutter/services.dart';

import 'ai_unavailability.dart';

/// Error codes from the native side. Use them to pick the right UI.
enum HybridAiErrorCode {
  invalidRequest,

  /// The scholarship data (title / source link) is empty, so the AI has no source to base an answer on.
  noContext,

  /// Private mode is on (cloud not allowed) but the device does not support Gemini Nano.
  privateModeUnavailable,

  /// The device does not support Gemini Nano.
  onDeviceUnsupported,

  /// Gemini Nano has not been downloaded: offer a "Download model" button.
  modelNotDownloaded,

  /// Gemini Nano is downloading: show progress and ask the user to wait.
  modelDownloading,

  /// Gemini Nano is in use by another app: try again in a moment.
  busy,
  quotaExceeded,

  /// The App Check token is not registered / invalid (cloud path).
  appCheckFailed,

  /// No internet connection (DNS failure, offline) on the cloud path.
  network,

  /// The cloud AI took too long to answer (timeout / `DEADLINE_EXCEEDED`). A timeout always wins over a
  /// network error, even when both are reported. Show "AI took too long. Try again."
  timeout,
  contentBlocked,
  emptyResponse,

  /// `google-services.json` is not installed in the app.
  firebaseNotConfigured,
  unknown,
}

/// An error from the hybrid_ai package, translated from `PlatformException`.
class HybridAiException implements Exception {
  const HybridAiException(this.code, this.rawCode, [this.message]);

  factory HybridAiException.fromPlatform(PlatformException e) =>
      HybridAiException(_codes[e.code] ?? HybridAiErrorCode.unknown, e.code, e.message);

  final HybridAiErrorCode code;

  /// The original code from Kotlin, e.g. `PRIVATE_MODE_UNAVAILABLE`.
  final String rawCode;

  /// Technical message (for logs), not meant to be shown to the user.
  final String? message;

  /// A friendly message to show to the student (English).
  String get userMessage => switch (code) {
        HybridAiErrorCode.privateModeUnavailable =>
          'Private mode is on, but this phone does not support on-device AI. Allow cloud AI in Settings to use the assistant.',
        HybridAiErrorCode.onDeviceUnsupported => 'This phone does not support on-device AI.',
        HybridAiErrorCode.modelNotDownloaded =>
          'The on-device AI model has not been downloaded yet. Download it to use the assistant without internet.',
        HybridAiErrorCode.modelDownloading =>
          'The AI model is still downloading. Wait for the download to finish, then try again.',
        HybridAiErrorCode.busy => 'The AI is busy. Try again in a few seconds.',
        HybridAiErrorCode.quotaExceeded => 'The AI usage limit has been reached. Try again later.',
        HybridAiErrorCode.appCheckFailed => 'This app has not been verified to use cloud AI.',
        HybridAiErrorCode.network =>
          'No connection. Cloud AI needs internet; on-device AI only works once the Gemini Nano model is ready on this phone.',
        HybridAiErrorCode.timeout => 'AI took too long. Try again.',
        HybridAiErrorCode.contentBlocked => "This question can't be answered. Try rephrasing it.",
        HybridAiErrorCode.emptyResponse => 'The AI did not return an answer. Try again.',
        HybridAiErrorCode.invalidRequest => 'The question is invalid or too long.',
        HybridAiErrorCode.noContext =>
          "Scholarship data is missing or incomplete, so the AI can't answer yet. Open the scholarship details first.",
        HybridAiErrorCode.firebaseNotConfigured => 'Firebase is not configured in this app.',
        HybridAiErrorCode.unknown => 'The AI assistant is unavailable right now. Try again later.',
      };

  /// Explanation + suggested action to show when the AI is unavailable. One entry point for every error code.
  AiUnavailability get unavailability => AiUnavailability(
        title: _title,
        message: userMessage,
        action: _action,
      );

  String get _title => switch (code) {
        HybridAiErrorCode.privateModeUnavailable => 'Private mode is on',
        HybridAiErrorCode.onDeviceUnsupported => 'On-device AI not supported',
        HybridAiErrorCode.modelNotDownloaded => 'AI model not downloaded',
        HybridAiErrorCode.modelDownloading => 'AI model is downloading',
        HybridAiErrorCode.busy => 'AI is busy',
        HybridAiErrorCode.quotaExceeded => 'Usage limit reached',
        HybridAiErrorCode.appCheckFailed => 'App not verified',
        HybridAiErrorCode.network => 'No connection',
        HybridAiErrorCode.timeout => 'AI took too long',
        HybridAiErrorCode.contentBlocked => "Question can't be answered",
        HybridAiErrorCode.emptyResponse => 'No answer from the AI',
        HybridAiErrorCode.invalidRequest => 'Invalid question',
        HybridAiErrorCode.noContext => 'Scholarship data unavailable',
        HybridAiErrorCode.firebaseNotConfigured => 'Setup incomplete',
        HybridAiErrorCode.unknown => 'AI unavailable',
      };

  AiUnavailableAction get _action => switch (code) {
        HybridAiErrorCode.privateModeUnavailable => AiUnavailableAction.openPrivacySettings,
        HybridAiErrorCode.modelNotDownloaded => AiUnavailableAction.downloadModel,
        HybridAiErrorCode.modelDownloading => AiUnavailableAction.waitForDownload,
        HybridAiErrorCode.busy ||
        HybridAiErrorCode.quotaExceeded ||
        HybridAiErrorCode.network ||
        HybridAiErrorCode.timeout ||
        HybridAiErrorCode.emptyResponse ||
        HybridAiErrorCode.unknown =>
          AiUnavailableAction.retry,
        HybridAiErrorCode.contentBlocked || HybridAiErrorCode.invalidRequest => AiUnavailableAction.editQuestion,
        HybridAiErrorCode.noContext ||
        HybridAiErrorCode.onDeviceUnsupported ||
        HybridAiErrorCode.appCheckFailed ||
        HybridAiErrorCode.firebaseNotConfigured =>
          AiUnavailableAction.none,
      };

  static const _codes = <String, HybridAiErrorCode>{
    'INVALID_REQUEST': HybridAiErrorCode.invalidRequest,
    'NO_CONTEXT': HybridAiErrorCode.noContext,
    'PRIVATE_MODE_UNAVAILABLE': HybridAiErrorCode.privateModeUnavailable,
    'ON_DEVICE_UNSUPPORTED': HybridAiErrorCode.onDeviceUnsupported,
    'MODEL_NOT_DOWNLOADED': HybridAiErrorCode.modelNotDownloaded,
    'MODEL_DOWNLOADING': HybridAiErrorCode.modelDownloading,
    'BUSY': HybridAiErrorCode.busy,
    'QUOTA_EXCEEDED': HybridAiErrorCode.quotaExceeded,
    'APP_CHECK_FAILED': HybridAiErrorCode.appCheckFailed,
    'NETWORK': HybridAiErrorCode.network,
    'TIMEOUT': HybridAiErrorCode.timeout,
    'CONTENT_BLOCKED': HybridAiErrorCode.contentBlocked,
    'EMPTY_RESPONSE': HybridAiErrorCode.emptyResponse,
    'FIREBASE_NOT_CONFIGURED': HybridAiErrorCode.firebaseNotConfigured,
  };

  @override
  String toString() => 'HybridAiException($rawCode${message == null ? '' : ': $message'})';
}
