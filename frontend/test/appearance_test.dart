import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/design/appearance.dart';
import 'package:lumina/design/customize_panel.dart';
import 'package:lumina/screens/ask_screen.dart';
import 'package:lumina/screens/browse_screen.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/theme.dart';
import 'package:lumina/widgets/common.dart';
import 'package:lumina/widgets/scholarship_card.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// The customizable look and the layouts that change with the window size.
void main() {
  // The active look is global; leave the default behind for other tests.
  tearDown(() => applyAppearance(const Appearance()));

  Future<AppController> pumpSignedIn(
    WidgetTester tester,
    Size size,
    AppearanceController look,
  ) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend = DemoBackend(loadCatalog());
    final c = AppController(backend: backend, ai: HybridAi(hostApi: FakeHost()), clock: () => testNow);
    await tester.pumpWidget(
      LuminaApp(controller: c, appearance: look, splashDuration: Duration.zero, googleFonts: false),
    );
    await tester.pumpAndSettle();
    // On a short phone with large text the welcome screen scrolls.
    await tester.ensureVisible(find.text('Continue with email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
    for (final button in ['Next', 'Next', 'Next', 'Finish']) {
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
    }
    // Let the "Profile set up" toast leave, so it covers nothing.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    return c;
  }

  test('settings survive saving and loading, and unknown values fall back to the default', () {
    const look = Appearance(accent: AccentPreset.plum, textSize: TextSize.large, dark: true);
    expect(Appearance.fromJson(look.toJson()), look);
    expect(
      Appearance.fromJson({'accent': 'neon', 'dark': 'yes', 'corners': 'round'}),
      const Appearance(corners: Corners.round),
    );
  });

  test('the language is saved, and resetting the look keeps it', () {
    const look = Appearance(language: AppLanguage.indonesian, dark: true);
    expect(Appearance.fromJson(look.toJson()), look);
    expect(Appearance.fromJson({'language': 'klingon'}).language, AppLanguage.english);
    final c = AppearanceController(initial: look)..reset();
    expect(c.value, const Appearance(language: AppLanguage.indonesian));
  });

  test('the phone and cloud answer labels are readable in every look', () {
    // WCAG AA for small text: at least 4.5 to 1.
    double contrast(Color a, Color b) {
      final x = a.computeLuminance() + 0.05, y = b.computeLuminance() + 0.05;
      return x > y ? x / y : y / x;
    }

    for (final dark in [false, true]) {
      for (final highContrast in [false, true]) {
        final palette = LPalette.of(Appearance(dark: dark, highContrast: highContrast));
        for (final tone in [palette.onPhone, palette.cloud]) {
          expect(contrast(tone.text, tone.fill), greaterThanOrEqualTo(4.5), reason: 'dark $dark, high $highContrast');
        }
      }
    }
  });

  testWidgets('Profile has a dark mode toggle and a language list', (tester) async {
    final look = AppearanceController();
    final c = await pumpSignedIn(tester, const Size(412, 915), look);
    c.setTab(3);
    await tester.pumpAndSettle();

    final darkMode = find.byWidgetPredicate((w) => w is LToggle && w.semanticLabel == 'Dark mode');
    expect(darkMode, findsOneWidget);
    await tester.tap(darkMode);
    await tester.pumpAndSettle();
    expect(look.value.dark, isTrue);

    expect(find.text('English'), findsOneWidget); // current language on the row
    await tester.tap(find.text('Language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bahasa Indonesia'));
    await tester.pumpAndSettle();
    expect(look.value.language, AppLanguage.indonesian);
    expect(look.value.dark, isTrue); // picking a language leaves the rest of the look alone
    expect(tester.takeException(), isNull);
  });

  testWidgets('a change on the panel restyles the open screen without losing its place', (tester) async {
    final look = AppearanceController();
    final c = await pumpSignedIn(tester, const Size(1366, 800), look);
    c.setTab(1);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Fulbright');
    await tester.pumpAndSettle();
    Color background() => Theme.of(tester.element(find.byType(BrowseScreen))).scaffoldBackgroundColor;
    final lightBackground = background();

    await tester.tap(find.text('Customize look'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomizePanel), findsOneWidget);
    final darkMode = find.byWidgetPredicate((w) => w is LToggle && w.semanticLabel == 'Dark mode');
    final panelList = find.descendant(of: find.byType(CustomizePanel), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(darkMode, 200, scrollable: panelList);
    await tester.pumpAndSettle();
    await tester.tap(darkMode);
    await tester.pumpAndSettle();

    expect(look.value.dark, isTrue);
    expect(background(), isNot(lightBackground));
    // Text drawn straight from the palette is repainted too, and the search is kept.
    expect(tester.widget<Text>(find.text('2 results')).style!.color, LColors.ink);
    expect(c.filters.query, 'Fulbright');
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide screens get a sidebar, side filters and cards in columns', (tester) async {
    final c = await pumpSignedIn(tester, const Size(1440, 900), AppearanceController());
    c.setTab(1);
    await tester.pumpAndSettle();

    expect(find.text('Customize look'), findsOneWidget); // sidebar
    expect(find.byType(FilterOptions), findsOneWidget); // no sheet needed
    expect(find.byTooltip('Filters'), findsNothing);
    final cards = find.byType(ScholarshipCard);
    expect(tester.getTopLeft(cards.at(0)).dy, tester.getTopLeft(cards.at(1)).dy);
  });

  testWidgets('on Android the panel is a sheet that the back button closes', (tester) async {
    final c = await pumpSignedIn(tester, const Size(390, 844), AppearanceController());
    c.setTab(3);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Customize look'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomizePanel), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CustomizePanel), findsNothing);
    expect(c.tab, 3);
  });

  // Overflowing layouts throw in widget tests, so walking the screens is the check.
  for (final (name, size) in [('small phone', const Size(320, 640)), ('tablet', const Size(920, 700))]) {
    for (final look in [
      const Appearance(),
      const Appearance(textSize: TextSize.extraLarge, spacing: Spacing.roomy, corners: Corners.round),
    ]) {
      testWidgets('no layout overflows on a $name with ${look.textSize.label} text', (tester) async {
        final c = await pumpSignedIn(tester, size, AppearanceController(initial: look));
        for (final tab in [0, 1, 2, 3]) {
          c.setTab(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: 'tab $tab');
        }

        c.setTab(1);
        await tester.pumpAndSettle();
        final title = find.text("Fulbright Master's Degree Scholarship");
        await tester.enterText(find.byType(TextField).first, 'Fulbright Master');
        await tester.pumpAndSettle();
        await tester.ensureVisible(title);
        await tester.tap(title);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'details');

        for (final action in ['Ask AI', 'Prepare']) {
          await tester.ensureVisible(find.text(action));
          await tester.tap(find.text(action));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: action);
          if (action == 'Ask AI') {
            // Sent from the keyboard: on a small phone the suggestions start off screen.
            await tester.enterText(find.byType(TextField).last, 'Am I eligible?');
            await tester.testTextInput.receiveAction(TextInputAction.send);
            await tester.pumpAndSettle();
            expect(find.byType(AiSourceLabel, skipOffstage: false), findsOneWidget);
            expect(tester.takeException(), isNull, reason: 'answer label');
          }
          await tester.tap(find.byTooltip('Back'));
          await tester.pumpAndSettle();
        }

        c.setSavedSegment('preparing');
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        c.setTab(2);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'saved list');
      });
    }
  }
}
