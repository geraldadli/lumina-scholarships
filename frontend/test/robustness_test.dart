import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/data/firebase_backend.dart';
import 'package:lumina/models/saved_scholarship.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/util/format.dart';

import 'fakes.dart';

/// Checklist writes are rejected, like a Firestore rules failure.
class _RejectingChecklist extends DemoBackend {
  _RejectingChecklist(super.catalog);

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) async {
    if (patch.checklist != null) throw Exception('permission-denied');
    return super.updateSaved(uid, scholarshipId, patch);
  }
}

void main() {
  test('a blank country code in one catalog doc does not break parsing', () {
    final s = scholarshipFromFirestore('x', {
      'title': 'X',
      'eligibleCitizenships': ['ID', '', ' '],
      'hostCountries': [' ', 'uk'],
    });
    expect(s.eligibleCitizenships, ['ID']);
    expect(s.hostCountries, ['GB']);
    expect(UserProfile.fromMap({'targetCountries': ['', 'jp']}).targetCountries, ['JP']);
  });

  test('notes are clipped to 5000 UTF-16 units without splitting an emoji', () {
    expect(clipUtf16('abc', 5000), 'abc');
    final notes = '${'a' * 4999}🎓🎓';
    final clipped = clipUtf16(notes, maxNotesLength);
    expect(clipped.length, 4999); // the emoji straddling the limit is dropped whole
    expect(clipped, 'a' * 4999);
  });

  test('the last hour before a deadline still counts as 1 day left', () {
    // 23:59:59 WIB on 21 Nov.
    final s = scholarshipFromFirestore('x', {'title': 'X', 'deadline': DateTime.utc(2026, 11, 21, 16, 59, 59)});
    expect(s.daysLeftAt(DateTime.utc(2026, 11, 21, 16, 30)), 1);
    expect(s.daysLeftAt(DateTime.utc(2026, 11, 20, 17)), 1);
    expect(s.daysLeftAt(DateTime.utc(2026, 11, 20, 16)), 2);
  });

  test('a regenerated checklist that fails to save shows no AI tips or AI badge', () async {
    final backend = _RejectingChecklist(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    await backend.save(c.user!.uid, c.byId('fulbright-masters-indonesia-2027')!);
    await pumpEventQueue();

    final msg = await c.regenerateChecklist(c.byId('fulbright-masters-indonesia-2027')!);
    expect(msg, 'Could not save your checklist. Try again.');
    expect(c.checklistTips, isEmpty);
    expect(c.checklistSource, isEmpty);
  });
}
