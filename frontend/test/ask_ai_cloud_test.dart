import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/data/privacy_store.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/widgets/common.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// Profile writes behave like Firestore: shown at once as pending (`savePending`), then
/// confirmed once [gate] opens, or dropped (the account's value comes back) when [reject].
class _FirestoreLikeBackend extends DemoBackend {
  _FirestoreLikeBackend(super.catalog);

  Completer<void>? gate;
  bool reject = false;
  final _confirmed = <String, UserProfile>{};

  /// The account's confirmed profile.
  UserProfile account(String uid) => _confirmed[uid]!;

  @override
  Future<void> saveProfile(String uid, UserProfile profile, {required bool isNew}) async {
    final before = _confirmed[uid];
    await super.saveProfile(uid, profile.copyWith(savePending: true), isNew: isNew);
    await gate?.future;
    if (reject) {
      if (before != null) await super.saveProfile(uid, before, isNew: false);
      throw Exception('permission-denied');
    }
    _confirmed[uid] = profile;
    await super.saveProfile(uid, profile, isNew: isNew);
  }
}

/// Ask AI with cloud AI off on a phone where on-device AI does not answer.
void main() {
  late FakeHost host;
  late _FirestoreLikeBackend backend;
  late MemoryPrivacyStore store;
  late AppController controller;

  Future<void> openAsk(WidgetTester tester, {required String error, ModelAvailability device = ModelAvailability.unavailable}) async {
    tester.view
      ..physicalSize = const Size(1179, 2556)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    backend = _FirestoreLikeBackend(loadCatalog());
    store = MemoryPrivacyStore();
    host = FakeHost(availability: device)..askErrorWithoutCloud = PlatformException(code: error);
    controller = AppController(backend: backend, ai: HybridAi(hostApi: host), clock: () => testNow, privacyStore: store);
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
    expect(host.asked.single.allowCloud, isFalse);
  }

  /// Sends a new question from the keyboard (a toast may cover the Send button).
  Future<void> askAnother(WidgetTester tester) async {
    final before = host.asked.length;
    await tester.enterText(find.byType(TextField).last, 'What documents do I need?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(host.asked, hasLength(before + 1));
  }

  /// Closes the app and opens it again: same account, same phone storage, new controller.
  Future<void> restart(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    controller = AppController(backend: backend, ai: HybridAi(hostApi: host), clock: () => testNow, privacyStore: store);
    await tester.pumpWidget(LuminaApp(controller: controller, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();
    expect(controller.user, isNotNull); // still signed in
  }

  /// Asks a question straight through the controller; returns whether it went with cloud AI.
  Future<bool> askNow(WidgetTester tester) async {
    await controller.ask(controller.byId(fulbrightMasters)!, 'What documents do I need?');
    await tester.pumpAndSettle();
    return host.asked.last.allowCloud;
  }

  void expectCloudAnswer() {
    expect(host.asked.last.allowCloud, isTrue);
    expect(find.text('Answered with cloud AI'), findsOneWidget);
    expect(find.text('Cloud AI is turned off'), findsNothing);
    expect(find.text('Cloud AI is on now'), findsNothing);
  }

  testWidgets('header has no mode badge; the label under a cloud answer says where it ran', (tester) async {
    // The phone has the on-device model, yet this answer comes from the cloud.
    await openAsk(tester, error: 'ON_DEVICE_UNAVAILABLE', device: ModelAvailability.available);
    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expectCloudAnswer();
    for (final badge in ['On-device', 'Cloud AI', 'AI off']) {
      expect(find.text(badge), findsNothing);
    }
    expect(find.text('Answers use only the official scholarship page.'), findsOneWidget);
  });

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

    // This question went with cloud AI (the tap is consent for it), but the setting only
    // counts for the next questions once Firestore confirms it.
    expect(controller.cloudAllowed, isFalse);
    expect(controller.cloudSwitch, isTrue);

    backend.gate!.complete();
    await tester.pumpAndSettle();
    expect(controller.cloudAllowed, isTrue);
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

  testWidgets('Allow cloud AI fails to save: says the question was sent, then cloud AI is off again', (tester) async {
    await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');

    backend.reject = true;
    await tester.tap(find.text('Allow cloud AI'));
    await tester.pumpAndSettle();
    expectCloudAnswer();
    expect(
      find.text('Your question was sent with cloud AI, but the setting could not be saved, '
          'so cloud AI is still off for your next questions.'),
      findsOneWidget,
    );
    expect(controller.cloudAllowed, isFalse);

    // The next question stays on the phone.
    await askAnother(tester);
    expect(host.asked.last.allowCloud, isFalse);
  });

  testWidgets('turning cloud AI on in Privacy & AI fails to save: it stays off and says so', (tester) async {
    await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');

    backend.reject = true;
    expect(await controller.setCloudAllowed(true), isFalse);
    await tester.pumpAndSettle();
    expect(find.text('Could not turn on cloud AI, so it is still off. Try again.'), findsOneWidget);
    expect(controller.cloudAllowed, isFalse);
    expect(host.asked, hasLength(1)); // nothing was sent
  });

  group('turning cloud AI off fails to save', () {
    Future<void> turnOffAndFail(WidgetTester tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      expect(await controller.setCloudAllowed(true), isTrue);
      await tester.pumpAndSettle();
      expect(controller.profile!.cloudAiAllowed, isTrue); // saved to the account

      backend.reject = true;
      expect(await controller.setCloudAllowed(false), isFalse);
      await tester.pumpAndSettle();
    }

    testWidgets('cloud AI stays off on the phone and the message says so', (tester) async {
      await turnOffAndFail(tester);
      expect(
        find.text('Could not save that to your account, but cloud AI is off on this phone. Try again to save it.'),
        findsOneWidget,
      );
      expect(controller.profile!.cloudAiAllowed, isTrue); // the account still says on...
      expect(controller.cloudAllowed, isFalse); // ...but this phone keeps it off

      await askAnother(tester);
      expect(host.asked.last.allowCloud, isFalse);
    });

    testWidgets('a later "on" from the account does not turn it back on', (tester) async {
      await turnOffAndFail(tester);

      // Firestore drops the rejected write and the listener reports the saved "on" again.
      backend.reject = false;
      await backend.saveProfile(
        controller.user!.uid,
        controller.profile!.copyWith(cloudAiAllowed: true),
        isNew: false,
      );
      await tester.pumpAndSettle();
      expect(controller.cloudAllowed, isFalse);
    });

    testWidgets('the next profile save stores "off" to the account', (tester) async {
      await turnOffAndFail(tester);

      backend.reject = false;
      // e.g. Edit preferences, whose draft still holds the account's "on".
      await controller.saveProfile(controller.profile!.copyWith(displayName: 'Kevin S'));
      await tester.pumpAndSettle();
      expect(controller.profile!.cloudAiAllowed, isFalse);
      expect(controller.profile!.displayName, 'Kevin S');
      expect(controller.cloudAllowed, isFalse);
    });

    testWidgets('turning it on again and saving brings cloud AI back', (tester) async {
      await turnOffAndFail(tester);

      backend.reject = false;
      expect(await controller.setCloudAllowed(true), isTrue);
      await tester.pumpAndSettle();
      expect(controller.cloudAllowed, isTrue);
    });
  });

  group('restart', () {
    testWidgets('an Off that failed to save is still off after a restart', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      expect(await controller.setCloudAllowed(true), isTrue);
      backend.reject = true;
      expect(await controller.setCloudAllowed(false), isFalse);
      await tester.pumpAndSettle();

      await restart(tester);
      expect(controller.profile!.cloudAiAllowed, isTrue); // the account still has the old "on"
      expect(controller.cloudAllowed, isFalse);
      expect(controller.cloudSwitch, isFalse);
      expect(await askNow(tester), isFalse);
    });

    testWidgets('an Off still saving when the app closes is still off after a restart', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      expect(await controller.setCloudAllowed(true), isTrue);
      backend.gate = Completer<void>(); // Firestore never confirms before the app closes
      unawaited(controller.setCloudAllowed(false));
      await tester.pumpAndSettle();

      await restart(tester);
      expect(controller.cloudAllowed, isFalse);
      expect(await askNow(tester), isFalse);
    });

    testWidgets('after a restart the remembered Off is saved to the account, then forgotten', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      expect(await controller.setCloudAllowed(true), isTrue);
      backend.reject = true;
      expect(await controller.setCloudAllowed(false), isFalse);
      await tester.pumpAndSettle();
      expect(await store.unsavedCloudOff(controller.user!.uid), isTrue);

      backend.reject = false;
      await restart(tester);
      expect(backend.account(controller.user!.uid).cloudAiAllowed, isFalse);
      expect(await store.unsavedCloudOff(controller.user!.uid), isFalse);
      expect(controller.cloudAllowed, isFalse);

      // Turning it on again works as usual.
      expect(await controller.setCloudAllowed(true), isTrue);
      await tester.pumpAndSettle();
      expect(controller.cloudAllowed, isTrue);
    });

    testWidgets('an On Firestore has not confirmed does not count after a restart', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      backend.gate = Completer<void>();
      unawaited(controller.setCloudAllowed(true));
      await tester.pumpAndSettle();

      await restart(tester);
      expect(controller.profile!.cloudAiAllowed, isTrue);
      expect(controller.profile!.savePending, isTrue);
      expect(controller.cloudAllowed, isFalse);
      expect(await askNow(tester), isFalse);
    });
  });

  group('turning cloud AI on from Privacy & AI', () {
    testWidgets('questions stay on the phone until Firebase confirms it', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      backend.gate = Completer<void>();
      final saving = controller.setCloudAllowed(true);
      await tester.pumpAndSettle();
      expect(controller.cloudSwitch, isTrue); // the switch shows the choice...
      expect(controller.cloudSaving, isTrue);
      expect(controller.cloudAllowed, isFalse); // ...but questions do not use cloud AI yet
      expect(await askNow(tester), isFalse);

      backend.gate!.complete();
      expect(await saving, isTrue);
      await tester.pumpAndSettle();
      expect(controller.cloudAllowed, isTrue);
      expect(await askNow(tester), isTrue);
    });

    testWidgets('an On rejected after a wait never sent a question to the cloud', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      backend
        ..gate = Completer<void>()
        ..reject = true;
      final saving = controller.setCloudAllowed(true);
      await tester.pumpAndSettle();
      expect(await askNow(tester), isFalse);

      backend.gate!.complete();
      expect(await saving, isFalse);
      await tester.pumpAndSettle();
      expect(controller.cloudAllowed, isFalse);
      expect(controller.cloudSwitch, isFalse);
      expect(host.asked.where((r) => r.allowCloud), isEmpty);
    });

    testWidgets('the switch shows the choice with a saving note', (tester) async {
      await openAsk(tester, error: 'PRIVATE_MODE_UNAVAILABLE');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Profile').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Privacy & AI'));
      await tester.pumpAndSettle();

      expect(find.text('On-device AI model'), findsOneWidget); // on Privacy & AI

      backend.gate = Completer<void>();
      await tester.tap(find.byType(LToggle));
      await tester.pumpAndSettle();
      expect(find.text('Saving… Cloud AI is used once your account has this setting.'), findsOneWidget);
      expect(find.text('AI off'), findsWidgets); // inference mode: not yet

      backend.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.textContaining('Saving…'), findsNothing);
      expect(find.text('Cloud AI'), findsWidgets);
    });
  });
}
