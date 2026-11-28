import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/screens/ask_screen.dart';
import 'package:lumina/widgets/logo_motion.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// Sprint 1 path on the demo backend: sign in → onboarding → browse → details → save → Ask AI.
void main() {
  late FakeHost host;
  late DemoBackend backend;
  late AppController controller;
  late DateTime now;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844) * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    host = FakeHost();
    now = testNow;
    backend = DemoBackend(loadCatalog());
    controller = AppController(
      backend: backend,
      ai: HybridAi(hostApi: host),
      clock: () => now,
    );
    await tester.pumpWidget(LuminaApp(controller: controller, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();
  }

  Future<void> signInAndOnboard(WidgetTester tester) async {
    expect(find.text('Continue with email'), findsOneWidget);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();

    expect(find.text('About you'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Kevin Sukias');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Study goals'), findsOneWidget);
    await tester.tap(find.text('Masters'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Academics'), findsOneWidget);
    expect(find.textContaining('CV'), findsNothing); // CV import is hidden for now
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Privacy & AI'), findsOneWidget);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();
  }

  Future<void> openFulbrightMasters(WidgetTester tester) async {
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fulbright Master');
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
  }

  testWidgets('sign in, onboard, browse, open details, save', (tester) async {
    await pumpApp(tester);
    await signInAndOnboard(tester);

    expect(find.text('Hi, Kevin'), findsOneWidget);
    expect(controller.profile!.onboardingCompleted, isTrue);
    expect(controller.profile!.educationLevel, 'masters');

    await openFulbrightMasters(tester);
    expect(find.text('Key facts'), findsOneWidget);
    expect(find.text('15 Feb 2027'), findsOneWidget);
    expect(find.text('Apply on official website'), findsOneWidget);

    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(controller.isSaved('fulbright-masters-indonesia-2027'), isTrue);
    expect(find.text('Saved. Track it in the Saved tab'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove from saved'));
    await tester.pumpAndSettle();
    expect(controller.isSaved('fulbright-masters-indonesia-2027'), isFalse);
  });

  testWidgets('Ask AI answers with the official link and the scholarship as context', (tester) async {
    await pumpApp(tester);
    await signInAndOnboard(tester);
    await openFulbrightMasters(tester);

    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Am I eligible?'));
    await tester.pumpAndSettle();

    expect(host.asked.single.scholarship.id, 'fulbright-masters-indonesia-2027');
    expect(host.asked.single.allowCloud, isFalse); // private mode by default
    expect(find.text('The deadline is 2027-02-15.'), findsOneWidget);
    expect(find.text('aminef.or.id'), findsOneWidget); // official source chip
  });

  testWidgets('a twinkling star with steps shows while the AI writes, ending on the last step', (tester) async {
    await pumpApp(tester);
    await signInAndOnboard(tester);
    await openFulbrightMasters(tester);
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    host.askGate = Completer<void>();
    await tester.tap(find.text('Am I eligible?'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(TypingBubble), findsOneWidget);
    expect(find.byType(TwinkleMark), findsOneWidget);
    expect(find.text('Reading your question…'), findsOneWidget);

    // The steps move on every 1.7 s and stop at the last one.
    await tester.pump(const Duration(milliseconds: 1800));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Checking your eligibility…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Writing your answer…'), findsOneWidget);

    host.askGate!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TypingBubble), findsNothing);
    expect(find.text('The deadline is 2027-02-15.'), findsOneWidget);
  });

  testWidgets('backend demo listings: new one in Browse, saved one closes and shows Closed + Updated', (tester) async {
    await pumpApp(tester);
    await signInAndOnboard(tester);

    // The new listing from the research update shows up in Browse.
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Australia Awards');
    await tester.pumpAndSettle();
    expect(find.text('Australia Awards Scholarships'), findsOneWidget);

    // Save the open demo listing before its deadline.
    await tester.enterText(find.byType(TextField).first, 'Fulbright Master');
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    expect(find.text('Apply on official website'), findsOneWidget);
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(controller.isSaved(fulbrightMasters), isTrue);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // The deadline passes and the backend's deadline job closes it.
    now = DateTime.utc(2027, 2, 16, 3);
    backend.setCatalog(runDeadlineJob(now));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Closed: 15 Feb'), findsOneWidget);
    expect(find.text('UPDATED'), findsOneWidget);
    expect(find.text(closedSummary), findsOneWidget);

    // Details: what changed, the official source, and Ask AI / Prepare still there.
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('View official source'), findsOneWidget);
    expect(find.text('Apply on official website'), findsNothing);
    expect(find.text('Ask AI'), findsOneWidget);
    expect(find.text('Prepare'), findsOneWidget);

    // Opening the details marks the change as seen, so the badge goes away.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Closed: 15 Feb'), findsOneWidget);
    expect(find.text('UPDATED'), findsNothing);
  });

  testWidgets('AI unavailable shows the cloud-off card with actions', (tester) async {
    await pumpApp(tester);
    await signInAndOnboard(tester);
    await openFulbrightMasters(tester);
    host.askError = PlatformException(code: 'MODEL_NOT_DOWNLOADED');

    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('What documents do I need?'));
    await tester.pumpAndSettle();

    expect(find.text('Cloud AI is turned off'), findsOneWidget);
    expect(find.text('Allow cloud AI'), findsOneWidget);

    host.askError = null;
    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expect(controller.cloudAllowed, isTrue);
    expect(host.asked.last.allowCloud, isTrue);
    expect(find.text('Cloud AI is turned off'), findsNothing);
  });
}
