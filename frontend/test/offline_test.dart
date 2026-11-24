import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/backend.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/saved_scholarship.dart';
import 'package:lumina/models/scholarship.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// Firestore on a phone that goes into airplane mode, in front of [server].
///
/// Offline, the catalog listener keeps what it already loaded (the local cache) and server
/// changes wait until the phone is back online. Saved-scholarship writes show up at once
/// (latency compensation) but their futures only complete once the server confirms them
/// (or rejects them: [rejectWrites]).
class _AirplaneModeBackend implements LuminaBackend {
  _AirplaneModeBackend(this.server);

  final DemoBackend server;

  bool _online = true;
  final _reconnected = StreamController<void>.broadcast(sync: true);

  bool get online => _online;
  set online(bool value) {
    _online = value;
    if (value) _reconnected.add(null);
  }

  /// The server refuses writes once it sees them, like a Firestore rules failure.
  bool rejectWrites = false;

  Future<void> _confirmed() async {
    if (!_online) await _reconnected.stream.first;
    if (rejectWrites) throw Exception('permission-denied');
  }

  /// The last catalog the phone received: what a listener opened offline gets from the cache.
  List<Scholarship>? _cache;

  @override
  Stream<List<Scholarship>> scholarships() => Stream<List<Scholarship>>.multi((sink) {
        List<Scholarship>? waiting;
        void deliver(List<Scholarship> list) {
          _cache = list;
          sink.add(list);
        }

        if (!_online && _cache != null) sink.add(_cache!);
        final fromServer = server.scholarships().listen((list) {
          if (_online) {
            deliver(list);
          } else {
            waiting = list;
          }
        }, onError: sink.addError);
        final reconnects = _reconnected.stream.listen((_) {
          if (waiting case final list?) {
            waiting = null;
            deliver(list);
          }
        });
        sink.onCancel = () {
          fromServer.cancel();
          reconnects.cancel();
        };
      });

  @override
  Stream<Map<String, SavedScholarship>> saved(String uid) => server.saved(uid);

  @override
  Future<void> save(
    String uid,
    Scholarship s, {
    double? matchScore,
    String status = 'saved',
    List<ChecklistEntry> checklist = const [],
  }) async {
    await server.save(uid, s, matchScore: matchScore, status: status, checklist: checklist);
    await _confirmed();
  }

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) async {
    await server.updateSaved(uid, scholarshipId, patch);
    await _confirmed();
  }

  @override
  Future<void> unsave(String uid, String scholarshipId) async {
    await server.unsave(uid, scholarshipId);
    await _confirmed();
  }

  // Sign-in and the profile are not part of this test: straight through.
  @override
  bool get isDemo => server.isDemo;
  @override
  Stream<AuthUser?> authState() => server.authState();
  @override
  Future<void> signInWithGoogle() => server.signInWithGoogle();
  @override
  Future<void> signInWithEmail(String email, String password) => server.signInWithEmail(email, password);
  @override
  Future<void> createAccountWithEmail(String email, String password) => server.createAccountWithEmail(email, password);
  @override
  Future<void> sendPasswordReset(String email) => server.sendPasswordReset(email);
  @override
  Future<void> signOut() => server.signOut();
  @override
  Future<void> deleteAccount(String uid, {String? password}) => server.deleteAccount(uid, password: password);
  @override
  Stream<UserProfile?> profile(String uid) => server.profile(uid);
  @override
  Future<void> saveProfile(String uid, UserProfile profile, {required bool isNew}) =>
      server.saveProfile(uid, profile, isNew: isNew);
}

void main() {
  late DemoBackend server;
  late _AirplaneModeBackend network;
  late AppController controller;
  late DateTime now;

  Future<void> pumpSignedIn(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    now = testNow;
    server = DemoBackend(loadCatalog());
    network = _AirplaneModeBackend(server);
    controller = AppController(backend: network, ai: HybridAi(hostApi: FakeHost()), clock: () => now);
    await tester.pumpWidget(LuminaApp(controller: controller, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();

    await server.signInWithEmail('kevin@example.com', 'secret123');
    await tester.pumpAndSettle();
    await server.saveProfile(
      controller.user!.uid,
      const UserProfile(displayName: 'Kevin', educationLevel: 'masters', onboardingCompleted: true),
      isNew: true,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.bySemanticsLabel(label).last);
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField).first, text);
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  }

  testWidgets('airplane mode: loaded listings still open, and updates come through once back online', (tester) async {
    await pumpSignedIn(tester);

    // Online: open Browse and save the open Fulbright listing, then open Saved.
    await openTab(tester, 'Browse');
    await search(tester, 'Fulbright Master');
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(controller.isSaved(fulbrightMasters), isTrue);
    await back(tester);
    await openTab(tester, 'Saved');
    expect(find.text("Fulbright Master's Degree Scholarship"), findsOneWidget);

    // Airplane mode on. Meanwhile the deadline passes and the backend's deadline job closes it.
    network.online = false;
    now = DateTime.utc(2027, 2, 16, 3);
    server.setCatalog(runDeadlineJob(now));
    await tester.pumpAndSettle();
    expect(controller.scholarships, isNotEmpty);
    expect(controller.catalogError, isNull);

    // Saved still lists it (tapping the tab redraws it with the moved clock).
    // The phone's clock knows the deadline passed, but the backend's change has not arrived,
    // so there is no Updated badge or change summary yet.
    await openTab(tester, 'Saved');
    expect(find.text('Closed: 15 Feb'), findsOneWidget);
    expect(find.text('UPDATED'), findsNothing);
    expect(find.text(closedSummary), findsNothing);

    // The saved listing still opens.
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    expect(find.text('Key facts'), findsOneWidget);
    expect(find.text('What changed'), findsNothing);
    expect(find.text('View official source'), findsOneWidget);
    await back(tester);

    // A listing loaded in Browse still opens.
    await openTab(tester, 'Browse');
    await search(tester, 'Australia Awards');
    await tester.tap(find.text('Australia Awards Scholarships'));
    await tester.pumpAndSettle();
    expect(find.text('Key facts'), findsOneWidget);
    expect(find.text('Apply on official website'), findsOneWidget);
    await back(tester);

    // Airplane mode off: the backend's change comes through.
    network.online = true;
    await tester.pumpAndSettle();
    await openTab(tester, 'Saved');
    expect(find.text('Closed: 15 Feb'), findsOneWidget);
    expect(find.text('UPDATED'), findsOneWidget);
    expect(find.text(closedSummary), findsOneWidget);

    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('View official source'), findsOneWidget);
  });

  testWidgets('saving offline shows its toast at once, not when back online', (tester) async {
    await pumpSignedIn(tester);
    await openTab(tester, 'Browse');
    await search(tester, 'Fulbright Master');

    network.online = false;
    await tester.tap(find.byTooltip('Save').first);
    await tester.pumpAndSettle();
    expect(find.text('Saved. Track it in the Saved tab'), findsOneWidget);
    expect(find.byTooltip('Remove from saved'), findsOneWidget);

    // Saved lists it while still offline.
    await openTab(tester, 'Saved');
    expect(find.text("Fulbright Master's Degree Scholarship"), findsOneWidget);

    // Removing it offline answers at once too.
    await openTab(tester, 'Browse');
    await tester.tap(find.byTooltip('Remove from saved').first);
    await tester.pumpAndSettle();
    expect(find.text('Removed from saved'), findsOneWidget);
    expect(controller.isSaved(fulbrightMasters), isFalse);

    // Back online the server confirms both: no error toast.
    network.online = true;
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not'), findsNothing);
  });

  testWidgets('a save the server rejects still shows an error toast', (tester) async {
    await pumpSignedIn(tester);
    await openTab(tester, 'Browse');
    await search(tester, 'Fulbright Master');

    network.rejectWrites = true;
    await tester.tap(find.byTooltip('Save').first);
    await tester.pumpAndSettle();
    expect(find.text('Could not save it. Try again.'), findsOneWidget);
  });
}
