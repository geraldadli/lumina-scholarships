import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/saved_scholarship.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/screens/prepare_screen.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/state/browse_filters.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

const _fulbright = 'fulbright-masters-indonesia-2027';

/// Records every saved-scholarship update with the account it was written to.
class _WriteLog extends DemoBackend {
  _WriteLog(super.catalog);

  final updates = <({String uid, SavedPatch patch})>[];

  /// When set, checklist writes wait for it, like Firestore still confirming the save.
  Completer<void>? checklistWriteGate;

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) async {
    updates.add((uid: uid, patch: patch));
    if (patch.checklist != null) await checklistWriteGate?.future;
    return super.updateSaved(uid, scholarshipId, patch);
  }
}

Future<void> _onboardAndSave(_WriteLog backend, AppController c, Future<void> Function() settle) async {
  await backend.saveProfile(
    c.user!.uid,
    const UserProfile(displayName: 'Kevin', educationLevel: 'masters', onboardingCompleted: true),
    isNew: true,
  );
  await backend.save(c.user!.uid, c.byId(_fulbright)!);
  await settle();
}

void main() {
  test('an AI checklist started in one account is never written into the next one', () async {
    final backend = _WriteLog(loadCatalog());
    final host = FakeHost()..checklistGate = Completer<void>();
    final c = AppController(backend: backend, ai: HybridAi(hostApi: host), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    final accountA = c.user!.uid;
    await _onboardAndSave(backend, c, pumpEventQueue);

    final pending = c.regenerateChecklist(c.byId(_fulbright)!);
    await pumpEventQueue();

    // Switch account while the AI is still working. B has the same scholarship saved.
    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    expect(c.user!.uid, isNot(accountA));
    await _onboardAndSave(backend, c, pumpEventQueue);
    expect(c.isSaved(_fulbright), isTrue);

    host.checklistGate!.complete();
    await pending;
    await pumpEventQueue();

    expect(backend.updates.where((u) => u.patch.checklist != null), isEmpty);
    expect(c.checklistTips, isEmpty);
    expect(c.checklistSource, isEmpty);
  });

  test("account A's AI tips never reach account B when the switch happens while Firestore confirms", () async {
    final backend = _WriteLog(loadCatalog())..checklistWriteGate = Completer<void>();
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    final accountA = c.user!.uid;
    await _onboardAndSave(backend, c, pumpEventQueue);

    final pending = c.regenerateChecklist(c.byId(_fulbright)!);
    await pumpEventQueue();
    // The AI has answered and the checklist write to A has started, but is not confirmed yet.
    expect(backend.updates.where((u) => u.patch.checklist != null).map((u) => u.uid), [accountA]);

    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    await _onboardAndSave(backend, c, pumpEventQueue); // B has the same scholarship saved
    expect(c.checklistTips, isEmpty);

    backend.checklistWriteGate!.complete(); // Firestore confirms A's write
    await pending;
    await pumpEventQueue();

    expect(c.checklistTips, isEmpty);
    expect(c.checklistSource, isEmpty);
  });

  test('AI tips from one account do not show after switching to another', () async {
    final backend = _WriteLog(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    await _onboardAndSave(backend, c, pumpEventQueue);
    await c.regenerateChecklist(c.byId(_fulbright)!);
    expect(c.checklistTips[_fulbright], isNotEmpty);

    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    expect(c.checklistTips, isEmpty);
    expect(c.checklistSource, isEmpty);
  });

  test('notes queued for one account are dropped, not written, once another is signed in', () async {
    final backend = _WriteLog(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    final accountA = c.user!.uid;
    await _onboardAndSave(backend, c, pumpEventQueue);
    final notices = <String>[];
    c.notices.listen(notices.add);

    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    await _onboardAndSave(backend, c, pumpEventQueue); // B has it saved too
    expect(c.isSaved(_fulbright), isTrue);

    expect(await c.setNotes(c.byId(_fulbright)!, 'from account A', uid: accountA), isFalse);
    await pumpEventQueue();
    expect(backend.updates, isEmpty);
    expect(notices, isEmpty); // nothing for account B to act on
  });

  testWidgets('the last note edit is saved when leaving Prepare right away', (tester) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final backend = _WriteLog(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await tester.pump();
    final accountA = c.user!.uid;
    await _onboardAndSave(backend, c, tester.pump);
    await tester.pumpWidget(LuminaApp(controller: c, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Saved'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prepare'));
    await tester.pumpAndSettle();

    final notesField = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Add notes about this application…',
    );
    // The page's own list (text fields have scrollables of their own).
    final page = find.descendant(of: find.byType(PrepareScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(notesField, 300, scrollable: page);
    await tester.enterText(notesField, 'Ask for two references');
    // Leave before the 800 ms autosave fires.
    Navigator.of(tester.element(find.byType(PrepareScreen))).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(c.saved[_fulbright]!.notes, 'Ask for two references');
    expect(backend.updates.where((u) => u.patch.notes != null).map((u) => u.uid), [accountA]);
  });

  test('demo accounts keep their own profile and saved scholarships', () async {
    final backend = _WriteLog(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    await _onboardAndSave(backend, c, pumpEventQueue);

    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    expect(c.profile, isNull); // B starts with onboarding
    expect(c.saved, isEmpty);

    await backend.signOut();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    expect(c.profile!.displayName, 'Kevin');
    expect(c.isSaved(_fulbright), isTrue);
  });

  test('the Saved segment and Browse sort start fresh for the next account', () async {
    final backend = _WriteLog(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('a@lumina.test', 'secret123');
    await pumpEventQueue();
    c
      ..setSavedSegment('applied')
      ..filters.sort = SortBy.match;

    await backend.signOut();
    await backend.signInWithEmail('b@lumina.test', 'secret456');
    await pumpEventQueue();
    expect(c.savedSegment, 'saved');
    expect(c.filters.sort, SortBy.deadline);
  });
}

