import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:hybrid_ai/src/hybrid_ai.g.dart' show HybridAiHostApi;
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/scholarship.dart';

/// 21 Nov 2026, 10:00 WIB. Fixed so deadline-based assertions don't drift.
final testNow = DateTime.utc(2026, 11, 21, 3);

/// The real research data, as bundled for demo mode.
List<Scholarship> loadCatalog() => parseResearchJson(File('assets/demo/scholarships.json').readAsStringSync());

/// The demo listing that is open at [testNow] and closes on 15 Feb 2027.
const fulbrightMasters = 'fulbright-masters-indonesia-2027';
const closedSummary = 'Applications closed: the deadline of 15 February 2027 has passed.';

/// The bundled catalog after backend/src/process-deadlines.ts runs at [at]: active listings
/// past their deadline become closed with a change summary and a newer updatedAt.
List<Scholarship> runDeadlineJob(DateTime at) {
  // Deadlines as the app reads them: a date-only deadline is 23:59:59 WIB, not local midnight.
  final deadlines = {for (final s in loadCatalog()) s.id: s.deadline};
  final raw = jsonDecode(File('assets/demo/scholarships.json').readAsStringSync()) as List;
  for (final d in raw.cast<Map<String, dynamic>>()) {
    final deadline = deadlines[d['id']];
    if (d['status'] == 'active' && deadline != null && deadline.isBefore(at)) {
      expect(d['id'], anyOf(fulbrightMasters, 'fulbright-phd-indonesia-2027'));
      d['status'] = 'closed';
      d['changeSummary'] = closedSummary;
      // Demo data takes updatedAt from lastVerified; the job's serverTimestamp is "now".
      d['lastVerified'] = at.toIso8601String();
    }
  }
  return parseResearchJson(jsonEncode(raw));
}

/// Stand-in for the Kotlin side of hybrid_ai (same approach as the plugin's own tests).
class FakeHost implements HybridAiHostApi {
  FakeHost({this.askError, this.availability = ModelAvailability.downloadable});

  PlatformException? askError;

  /// Thrown only for questions sent without cloud AI, like the Kotlin side's on-device checks.
  PlatformException? askErrorWithoutCloud;
  final ModelAvailability availability;

  /// Where `ask` says its answer was made.
  AiSource answerSource = AiSource.cloud;

  /// When set, `generateChecklist` waits for it, like a slow AI call.
  Completer<void>? checklistGate;

  /// When set, `ask` waits for it, like the AI writing an answer.
  Completer<void>? askGate;
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
    await askGate?.future;
    if (askError != null) throw askError!;
    if (!request.allowCloud && askErrorWithoutCloud != null) throw askErrorWithoutCloud!;
    return AiAnswer(
      text: 'The deadline is ${request.scholarship.deadline}.',
      source: answerSource,
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
