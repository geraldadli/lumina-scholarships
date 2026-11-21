import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:hybrid_ai/src/hybrid_ai.g.dart' show HybridAiHostApi;
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/scholarship.dart';

/// 21 Nov 2026, 10:00 WIB. Fixed so deadline-based assertions don't drift.
final testNow = DateTime.utc(2026, 11, 21, 3);

/// The real research data, as bundled for demo mode.
List<Scholarship> loadCatalog() => parseResearchJson(File('assets/demo/scholarships.json').readAsStringSync());

/// Stand-in for the Kotlin side of hybrid_ai (same approach as the plugin's own tests).
class FakeHost implements HybridAiHostApi {
  FakeHost({this.askError, this.availability = ModelAvailability.downloadable});

  PlatformException? askError;
  final ModelAvailability availability;

  /// When set, `generateChecklist` waits for it, like a slow AI call.
  Completer<void>? checklistGate;
  final asked = <AskRequest>[];

  @override
  Future<AiStatus> getStatus() async => AiStatus(
        onDeviceModel: availability,
        inferenceMode: 'PREFER_ON_DEVICE',
        cloudModel: 'gemini-3.5-flash-lite',
        minMatchScore: 0.65,
        remoteConfigFetched: true,
      );

  @override
  Future<void> startModelDownload() async {}

  @override
  Future<AiAnswer> ask(AskRequest request) async {
    asked.add(request);
    if (askError != null) throw askError!;
    return AiAnswer(
      text: 'The deadline is ${request.scholarship.deadline}.',
      source: AiSource.cloud,
      latencyMs: 40,
      citations: const [],
    );
  }

  @override
  Future<ChecklistResult> generateChecklist(ChecklistRequest request) async {
    await checklistGate?.future;
    return ChecklistResult(
      items: [for (final r in request.scholarship.requirements) ChecklistItem(id: r.id, label: r.label, tip: 'Start early.')],
      source: AiSource.cloud,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
