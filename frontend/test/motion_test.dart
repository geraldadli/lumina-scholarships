import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/widgets/motion.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// The animations between pages.
void main() {
  Future<AppController> pumpWelcome(WidgetTester tester) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = DemoBackend(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow);
    await tester.pumpWidget(LuminaApp(controller: c, splashDuration: Duration.zero, googleFonts: false));
    await tester.pumpAndSettle();
    return c;
  }

  Future<AppController> pumpHome(WidgetTester tester) async {
    final c = await pumpWelcome(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    for (final button in ['Next', 'Next', 'Next', 'Finish']) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }
    return c;
  }

  /// How visible and how far from rest the page around [content] is.
  (double, double) page(WidgetTester tester, Finder content) {
    final switcher = find.ancestor(of: content, matching: find.byType(PageSwitch)).first;
    Finder inside(Type type) => find.descendant(of: switcher, matching: find.byType(type)).first;
    return (
      tester.widget<FadeTransition>(inside(FadeTransition)).opacity.value,
      tester.widget<SlideTransition>(inside(SlideTransition)).position.value.dx,
    );
  }

  testWidgets('switching tabs slides the new one in from its side and keeps what was typed', (tester) async {
    final c = await pumpHome(tester);

    c.setTab(1); // forward: comes from the right
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    var (opacity, dx) = page(tester, find.byType(TextField));
    expect(opacity, inExclusiveRange(0, 1));
    expect(dx, greaterThan(0));
    await tester.pumpAndSettle();
    expect(page(tester, find.byType(TextField)), (1.0, 0.0));
    await tester.enterText(find.byType(TextField), 'Fulbright');

    c.setTab(0); // back: comes from the left
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    (opacity, dx) = page(tester, find.text('Hi, there'));
    expect(dx, lessThan(0));
    await tester.pumpAndSettle();

    c.setTab(1);
    await tester.pumpAndSettle();
    expect(find.text('Fulbright'), findsOneWidget);
  });

  testWidgets('onboarding steps and Saved segments animate too', (tester) async {
    final c = await pumpWelcome(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(page(tester, find.text('Study goals')).$2, greaterThan(0));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(page(tester, find.text('About you')).$2, lessThan(0));
    await tester.pumpAndSettle();

    for (final button in ['Next', 'Next', 'Next', 'Finish']) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }
    c.setTab(2);
    await tester.pumpAndSettle();
    c.setSavedSegment('applied');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    // The innermost page switch is the segment's, inside the Saved tab's.
    final empty = find.text('Nothing in Applied yet');
    final segment = find.ancestor(of: empty, matching: find.byType(PageSwitch)).first;
    final fade = find.descendant(of: segment, matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
  });

  testWidgets('"remove animations" switches pages at once', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await pumpHome(tester);

    c.setTab(1);
    await tester.pump();
    expect(page(tester, find.byType(TextField)), (1.0, 0.0));
    await tester.pumpAndSettle();
  });
}
