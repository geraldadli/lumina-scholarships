/// Hybrid AI Lumina: Gemini Nano di perangkat dengan fallback cloud (Firebase AI Logic).
///
/// ```dart
/// final ai = HybridAi();
/// final status = await ai.getStatus();
/// final answer = await ai.ask(AskRequest(
///   question: 'Apa syarat bahasanya?',
///   scholarship: scholarshipContext,
///   student: studentContext,
///   allowCloud: user.privacy.cloudAiAllowed,
///   languageCode: 'id',
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

/// Pintu masuk tunggal ke fitur AI. Semua error dilempar sebagai [HybridAiException].
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

  /// Status Gemini Nano + konfigurasi Remote Config yang aktif.
  Future<AiStatus> getStatus() => _guard(_host.getStatus);

  /// Mengunduh Gemini Nano dan melaporkan progres. Stream selesai setelah
  /// [DownloadState.completed] atau [DownloadState.failed].
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

  /// Menjawab pertanyaan berdasarkan data beasiswa (grounded) dengan Nano atau cloud.
  Future<AiAnswer> ask(AskRequest request) => _guard(() => _host.ask(request));

  /// Checklist "Prepare". Tidak pernah gagal karena AI: bila AI tidak tersedia,
  /// hasilnya bersumber [AiSource.rules] dari syarat resmi.
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

/// Menerima progres unduhan dari Kotlin dan meneruskannya sebagai stream.
@visibleForTesting
class DownloadProgressRelay implements HybridAiFlutterApi {
  DownloadProgressRelay();

  /// Membuat relay dan mendaftarkannya ke kanal Pigeon (sekali per app).
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
