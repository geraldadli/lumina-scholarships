/// Lumina Hybrid AI: Gemini Nano on the device with a cloud fallback (Firebase AI Logic).
///
/// ```dart
/// final ai = HybridAi();
/// final status = await ai.getStatus();
/// final answer = await ai.ask(AskRequest(
///   question: 'What is the language requirement?',
///   scholarship: scholarshipContext,
///   student: studentContext,
///   allowCloud: user.privacy.cloudAiAllowed,
///   languageCode: 'en',
/// ));
/// ```
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'src/hybrid_ai.g.dart';
import 'src/hybrid_ai_exception.dart';

export 'src/hybrid_ai.g.dart'
    show
        AiAnswer,
        AiSource,
        AiStatus,
        AskRequest,
        ChecklistItem,
        ChecklistRequest,
        ChecklistResult,
        DownloadProgress,
        DownloadState,
        ModelAvailability,
        RequirementItem,
        ScholarshipContext,
        StudentContext;
export 'src/ai_unavailability.dart';
export 'src/hybrid_ai_exception.dart';
export 'src/match_scorer.dart';

/// The single entry point to the AI features. Every error is thrown as a [HybridAiException].
class HybridAi {
  HybridAi({
    @visibleForTesting HybridAiHostApi? hostApi,
    @visibleForTesting DownloadProgressRelay? relay,
  })  : _host = hostApi ?? HybridAiHostApi(),
        // Parameter bernama tidak boleh diawali `_`, jadi initializing formal tidak bisa dipakai.
        // ignore: prefer_initializing_formals
        _relay = relay;

  final HybridAiHostApi _host;
  DownloadProgressRelay? _relay;

  /// Gemini Nano status + the active Remote Config settings.
  Future<AiStatus> getStatus() => _guard(_host.getStatus);

  /// Downloads Gemini Nano and reports progress. The stream completes after
  /// [DownloadState.completed] or [DownloadState.failed].
  Stream<DownloadProgress> downloadModel() {
    final relay = _relay ??= DownloadProgressRelay.register();
    late final StreamController<DownloadProgress> controller;
    StreamSubscription<DownloadProgress>? sub;

    controller = StreamController<DownloadProgress>(
      onListen: () async {
        sub = relay.stream.listen((p) {
          controller.add(p);
          if (p.state == DownloadState.completed || p.state == DownloadState.failed) {
            sub?.cancel();
            controller.close();
          }
        });
        try {
          await _guard(_host.startModelDownload);
        } on HybridAiException catch (e) {
          controller.addError(e);
          await sub?.cancel();
          await controller.close();
        }
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Answers a question grounded in the scholarship data, using Nano or the cloud.
  Future<AiAnswer> ask(AskRequest request) => _guard(() => _host.ask(request));

  /// The "Prepare" checklist. Never fails because of the AI: when the AI is unavailable,
  /// the result comes from [AiSource.rules], built from the official requirements.
  Future<ChecklistResult> generateChecklist(ChecklistRequest request) =>
      _guard(() => _host.generateChecklist(request));

  static Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw HybridAiException.fromPlatform(e);
    }
  }
}

/// Receives download progress from Kotlin and forwards it as a stream.
@visibleForTesting
class DownloadProgressRelay implements HybridAiFlutterApi {
  DownloadProgressRelay();

  /// Creates the relay and registers it on the Pigeon channel (once per app).
  factory DownloadProgressRelay.register() {
    final relay = _registered ??= DownloadProgressRelay();
    HybridAiFlutterApi.setUp(relay);
    return relay;
  }

  static DownloadProgressRelay? _registered;
  final _controller = StreamController<DownloadProgress>.broadcast();

  Stream<DownloadProgress> get stream => _controller.stream;

  @override
  void onDownloadProgress(DownloadProgress progress) => _controller.add(progress);
}
