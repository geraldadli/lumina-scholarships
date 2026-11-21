import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/backend.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/saved_scholarship.dart';
import 'package:lumina/models/scholarship.dart';
import 'package:lumina/screens/auth_screens.dart';
import 'package:lumina/state/app_scope.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

const _fulbright = 'fulbright-masters-indonesia-2027';

/// A backend whose saved-scholarship updates are rejected, like a Firestore rules failure.
class _RejectingBackend extends DemoBackend {
  _RejectingBackend(super.catalog);

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) async =>
      throw Exception('permission-denied');
}

/// Signs in with email, finishes onboarding and saves Fulbright, straight through the backend.
///
/// [settle] lets stream updates through: `pumpEventQueue` in unit tests, `tester.pump` in widget
/// tests (the controller must subscribe inside the widget test's fake-async zone to get updates).
Future<AppController> _signedInWithSave(DemoBackend backend, {Future<void> Function() settle = pumpEventQueue}) async {
  final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
  await backend.signInWithEmail('kevin@example.com', 'secret123');
  await settle();
  await backend.saveProfile(
    c.user!.uid,
    const UserProfile(displayName: 'Kevin', educationLevel: 'masters', onboardingCompleted: true),
    isNew: true,
  );
  await backend.save(c.user!.uid, c.byId(_fulbright)!);
  await settle();
  return c;
}

void main() {
  group('deleting the account confirms the student before deleting anything', () {
    test('no password: nothing is deleted', () async {
      final backend = DemoBackend(loadCatalog());
      final c = await _signedInWithSave(backend);

      await expectLater(c.deleteAccount(), throwsA(isA<AuthFailure>()));
      await pumpEventQueue();
      expect(c.user, isNotNull);
      expect(c.isSaved(_fulbright), isTrue);
      expect(c.profile, isNotNull);
    });

    test('wrong password: nothing is deleted and the student stays signed in', () async {
      final backend = DemoBackend(loadCatalog());
      final c = await _signedInWithSave(backend);

      await expectLater(
        c.deleteAccount(password: 'wrong'),
        throwsA(isA<AuthFailure>().having((e) => e.message, 'message', 'Email or password is incorrect.')),
      );
      await pumpEventQueue();
      expect(c.user, isNotNull);
      expect(c.isSaved(_fulbright), isTrue);
    });

    test('right password: saved scholarships, profile and account are deleted', () async {
      final backend = DemoBackend(loadCatalog());
      final c = await _signedInWithSave(backend);
      expect(c.usesPassword, isTrue);

      await c.deleteAccount(password: 'secret123');
      await pumpEventQueue();
      expect(c.user, isNull);

      await backend.signInWithEmail('kevin@example.com', 'secret123');
      await pumpEventQueue();
      expect(c.saved, isEmpty);
      expect(c.profile, isNull);
    });
  });

  test('a rejected write is reported, and the action reports failure', () async {
    final c = await _signedInWithSave(_RejectingBackend(loadCatalog()));
    final notices = <String>[];
    c.notices.listen(notices.add);
    final s = c.byId(_fulbright)!;

    expect(await c.setStatus(s, 'applied'), isFalse);
    expect(await c.setNotes(s, 'Ask for two reference letters'), isFalse);
    expect(await c.setChecklist(s, const []), isFalse);
    await pumpEventQueue();

    expect(notices, [
      'Could not change the status. Try again.',
      'Could not save your notes.',
      'Could not save your checklist. Try again.',
    ]);
  });

  test("demo mode's one-tap sign-in has no password, so deleting needs none", () async {
    final backend = DemoBackend(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('', '');
    await pumpEventQueue();
    expect(c.usesPassword, isFalse);

    await c.deleteAccount();
    await pumpEventQueue();
    expect(c.user, isNull);
  });

  test('"Try again" reloads the catalog after it failed', () async {
    final backend = _RecordingBackend(loadCatalog())..failCatalog = true;
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow)..start();
    await backend.signInWithEmail('kevin@example.com', 'secret123');
    await pumpEventQueue();
    expect(c.catalogError, isNotNull);
    expect(c.scholarships, isEmpty);

    backend.failCatalog = false;
    c.retryCatalog();
    await pumpEventQueue();
    expect(c.catalogError, isNull);
    expect(c.byId(_fulbright), isNotNull);
  });

  testWidgets('Forgot password sends a reset link to the typed email', (tester) async {
    final backend = _RecordingBackend(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow);
    await tester.pumpWidget(AppScope(controller: c, child: const MaterialApp(home: EmailSignInScreen())));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email above, then tap "Forgot password?" again.'), findsOneWidget);
    expect(backend.resets, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, ' kevin@example.com ');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(backend.resets, ['kevin@example.com']);
    expect(find.textContaining('If an account uses kevin@example.com, a reset link is on its way.'), findsOneWidget);

    await tester.tap(find.text('Create a new account'));
    await tester.pumpAndSettle();
    expect(find.text('Forgot password?'), findsNothing); // only offered when signing in
  });

  group('app', () {
    late DemoBackend backend;
    late AppController controller;

    Future<void> pumpApp(WidgetTester tester, {DemoBackend? using}) async {
      tester.view
        ..physicalSize = const Size(390, 844) * 3
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      backend = using ?? DemoBackend(loadCatalog());
      controller = await _signedInWithSave(backend, settle: tester.pump);
      await tester.pumpWidget(LuminaApp(controller: controller, splashDuration: Duration.zero, googleFonts: false));
      await tester.pumpAndSettle();
    }

    testWidgets('a saved listing withdrawn from the catalog says so and can be removed', (tester) async {
      await pumpApp(tester);
      backend.setCatalog(loadCatalog().where((s) => s.id != _fulbright).toList());
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Saved'));
      await tester.pumpAndSettle();
      expect(find.text('This listing is no longer available'), findsOneWidget);
      expect(find.text('1 scholarship'), findsOneWidget);

      await tester.tap(find.text('Remove from saved'));
      await tester.pumpAndSettle();
      expect(controller.isSaved(_fulbright), isFalse);
      expect(find.text('Nothing saved yet'), findsOneWidget);
    });

    testWidgets('a failed write shows a toast, even with no screen open for it', (tester) async {
      await pumpApp(tester, using: _RejectingBackend(loadCatalog()));

      await controller.setNotes(controller.byId(_fulbright)!, 'Ask for two references');
      await tester.pump(); // deliver the notice
      await tester.pump(const Duration(milliseconds: 100)); // show the snackbar
      expect(find.text('Could not save your notes.'), findsOneWidget);
    });

    testWidgets('delete account asks for the password and keeps everything on a wrong one', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.bySemanticsLabel('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();

      final deleteButton = find.widgetWithText(TextButton, 'Delete');
      expect(tester.widget<TextButton>(deleteButton).onPressed, isNull); // no password yet

      await tester.enterText(find.byType(TextField), 'wrong');
      await tester.pump();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(controller.user, isNotNull);
      expect(controller.isSaved(_fulbright), isTrue);

      await tester.enterText(find.byType(TextField), 'secret123');
      await tester.pump();
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();
      expect(controller.user, isNull);
      expect(find.text('Continue with email'), findsOneWidget); // back on Welcome
    });
  });
}

/// Records reset requests and can fail the catalog once, like a dropped Firestore listener.
class _RecordingBackend extends DemoBackend {
  _RecordingBackend(super.catalog);

  final resets = <String>[];
  bool failCatalog = false;

  @override
  Future<void> sendPasswordReset(String email) async {
    await super.sendPasswordReset(email);
    resets.add(email);
  }

  @override
  Stream<List<Scholarship>> scholarships() =>
      failCatalog ? Stream.error(Exception('unavailable')) : super.scholarships();
}
