import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:hybrid_ai/src/hybrid_ai.g.dart' show HybridAiHostApi;

import 'match_scorer_test.dart' show scholarship;

class FakeHost implements HybridAiHostApi {
  FakeHost({this.error, this.relay, this.progress = const []});

  final PlatformException? error;
  final DownloadProgressRelay? relay;
  final List<DownloadProgress> progress;

  @override
  Future<AiStatus> getStatus() async {
    if (error != null) throw error!;
    return AiStatus(
      onDeviceModel: ModelAvailability.downloadable,
      inferenceMode: 'PREFER_ON_DEVICE',
      cloudModel: 'gemini-2.5-flash',
      minMatchScore: 0.65,
      remoteConfigFetched: true,
    );
  }

  @override
  Future<void> startModelDownload() async {
    if (error != null) throw error!;
    for (final p in progress) {
      scheduleMicrotask(() => relay!.onDownloadProgress(p));
    }
  }

  @override
  Future<AiAnswer> ask(AskRequest request) async {
    if (error != null) throw error!;
    return AiAnswer(text: 'Jawaban', source: AiSource.onDevice, latencyMs: 12, citations: [request.scholarship.sourceUrl]);
  }

  @override
  Future<ChecklistResult> generateChecklist(ChecklistRequest request) async =>
      ChecklistResult(items: [], source: AiSource.rules);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

AskRequest askRequest() => AskRequest(
      question: 'Apa syaratnya?',
      scholarship: scholarship(),
      allowCloud: false,
      languageCode: 'id',
    );

void main() {
  test('ask meneruskan jawaban dari native', () async {
    final answer = await HybridAi(hostApi: FakeHost()).ask(askRequest());
    expect(answer.text, 'Jawaban');
    expect(answer.source, AiSource.onDevice);
    expect(answer.citations, ['https://example.org']);
  });

  test('PlatformException diterjemahkan ke HybridAiException dengan kode yang dikenal', () async {
    final ai = HybridAi(hostApi: FakeHost(error: PlatformException(code: 'PRIVATE_MODE_UNAVAILABLE', message: 'x')));
    await expectLater(
      ai.ask(askRequest()),
      throwsA(isA<HybridAiException>()
          .having((e) => e.code, 'code', HybridAiErrorCode.privateModeUnavailable)
          .having((e) => e.userMessage, 'userMessage', contains('Mode privat'))),
    );
  });

  test('kode error tak dikenal menjadi unknown, kode asli tetap tersedia', () async {
    final ai = HybridAi(hostApi: FakeHost(error: PlatformException(code: 'channel-error')));
    await expectLater(
      ai.getStatus(),
      throwsA(isA<HybridAiException>()
          .having((e) => e.code, 'code', HybridAiErrorCode.unknown)
          .having((e) => e.rawCode, 'rawCode', 'channel-error')),
    );
  });

  test('downloadModel mengalirkan progres dan selesai saat completed', () async {
    final relay = DownloadProgressRelay();
    final ai = HybridAi(
      relay: relay,
      hostApi: FakeHost(relay: relay, progress: [
        DownloadProgress(state: DownloadState.started, totalBytes: 100),
        DownloadProgress(state: DownloadState.inProgress, bytesDownloaded: 50, totalBytes: 100),
        DownloadProgress(state: DownloadState.completed, totalBytes: 100),
      ]),
    );
    final states = await ai.downloadModel().map((p) => p.state).toList();
    expect(states, [DownloadState.started, DownloadState.inProgress, DownloadState.completed]);
  });

  test('downloadModel melempar HybridAiException bila native menolak', () async {
    final relay = DownloadProgressRelay();
    final ai = HybridAi(relay: relay, hostApi: FakeHost(relay: relay, error: PlatformException(code: 'ON_DEVICE_UNSUPPORTED')));
    await expectLater(
      ai.downloadModel().toList(),
      throwsA(isA<HybridAiException>().having((e) => e.code, 'code', HybridAiErrorCode.onDeviceUnsupported)),
    );
  });
}
