import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// Profile writes wait for [gate], like Firestore confirming over a slow network, or fail
/// when [reject] is set.
class _SlowProfileBackend extends DemoBackend {
  _SlowProfileBackend(super.catalog);

  Completer<void>? gate;
  bool reject = false;

  @override
  Future<void> saveProfile(String uid, UserProfile profile, {required bool isNew}) async {
    await gate?.future;
    if (reject) throw Exception('permission-denied');
    return super.saveProfile(uid, profile, isNew: isNew);
  }
}

/// Ask AI with cloud AI off on a phone where on-device AI does not answer.
void main() {
  late FakeHost host;
  late _SlowProfileBackend backend;
  late AppController controller;

  Future<void> openAsk(WidgetTester tester, {required String error, ModelAvailability device = ModelAvailability.unavailable}) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    backend = _SlowProfileBackend(loadCatalog());
    host = FakeHost(availability: device)..askErrorWithoutCloud = PlatformException(code: error);
    controller = AppController(backend: backend, ai: HybridAi(hostApi: host), clock: () => testNow);
    await tester.pumpWidget(LuminaApp(controller: controller, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();
    await backend.signInWithEmail('kevin@example.com', 'secret123');
    await tester.pumpAndSettle();
    await backend.saveProfile(
      controller.user!.uid,
      const UserProfile(displayName: 'Kevin', educationLevel: 'masters', onboardingCompleted: true),
      isNew: true,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Browse').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fulbright Master');
    await tester.pumpAndSettle();
    await tester.tap(find.text("Fulbright Master's Degree Scholarship"));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Am I eligible?'));
    await tester.pumpAndSettle();
    expect(find.text('AI off'), findsOneWidget);
    expect(host.asked.single.allowCloud, isFalse);
  }

  void expectCloudAnswer() {
    expect(host.asked.last.allowCloud, isTrue);
    expect(find.text('Answered with cloud AI'), findsOneWidget);
    expect(find.text('Cloud AI is turned off'), findsNothing);
    expect(find.text('Cloud AI is on now'), findsNothing);
  }

  testWidgets('phone without on-device AI: says why, and Allow cloud AI answers at once', (tester) async {
    await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
    expect(find.text('Cloud AI is turned off'), findsOneWidget);
    expect(find.textContaining('This phone does not support on-device AI'), findsOneWidget);
    expect(find.text('Allow cloud AI'), findsOneWidget);
    // The phone cannot run the on-device model, so there is nothing to download.
    expect(find.text('Download on-device model instead'), findsNothing);

    // Firestore has not confirmed the new setting yet: the retry must still use cloud AI.
    backend.gate = Completer<void>();
    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expect(host.asked, hasLength(2));
    expectCloudAnswer();
    expect(find.text('Am I eligible?'), findsNWidgets(2)); // the chip and one question: not asked twice

    backend.gate!.complete();
    await tester.pumpAndSettle();
    expect(controller.cloudAllowed, isTrue);
    expect(find.text('Cloud AI'), findsOneWidget);
  });

  testWidgets('on-device status unknown: explains cloud AI is off, offers it and Try again', (tester) async {
    await openAsk(tester, error: 'ON_DEVICE_UNAVAILABLE', device: ModelAvailability.unknown);
    expect(find.text('Cloud AI is turned off'), findsOneWidget);
    expect(find.textContaining('cloud AI is off'), findsOneWidget);
    expect(find.text('Allow cloud AI'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('Download on-device model instead'), findsNothing);

    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expectCloudAnswer();
  });

  testWidgets('on-device AI fails while answering: explains cloud AI is off and offers it', (tester) async {
    await openAsk(tester, error: 'ON_DEVICE_UNSUPPORTED');
    expect(find.text('Cloud AI is turned off'), findsOneWidget);
    expect(find.textContaining('This phone does not support on-device AI'), findsOneWidget);
    expect(find.text('Allow cloud AI'), findsOneWidget);
    expect(find.text('Download on-device model instead'), findsNothing);

    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expectCloudAnswer();
  });

  testWidgets('cloud AI turned on in Privacy & AI: the old card says to try again', (tester) async {
    await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');

    await controller.setCloudAllowed(true);
    await tester.pumpAndSettle();
    expect(find.text('Cloud AI is on now'), findsOneWidget);
    expect(find.text('Private mode is on'), findsNothing);
    expect(find.text('Open Privacy & AI'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expectCloudAnswer();
  });

  testWidgets('turning on cloud AI fails to save: says so and the setting goes back', (tester) async {
    await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');

    backend.reject = true;
    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expect(find.text('Could not turn on cloud AI. Try again.'), findsOneWidget);
    expect(controller.cloudAllowed, isFalse);
    expect(find.text('AI off'), findsOneWidget);
  });
}
