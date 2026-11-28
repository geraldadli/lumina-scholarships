import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:lumina/app.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/state/app_controller.dart';
import 'package:lumina/design/appearance.dart';
import 'package:lumina/design/customize_panel.dart';
import 'package:lumina/widgets/loading.dart';
import 'package:lumina/widgets/logo_motion.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

/// The loading screen shows the logo version that matches Lumina's own dark mode setting.
void main() {
  String shownLogo(WidgetTester tester) =>
      (tester.widget<SvgPicture>(find.byType(SvgPicture)).bytesLoader as SvgAssetLoader).assetName;

  Future<void> pumpSplash(WidgetTester tester, {required bool appDark, Brightness phone = Brightness.light}) async {
    tester.platformDispatcher.platformBrightnessTestValue = phone;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(AppearanceScope(
      controller: AppearanceController(initial: Appearance(dark: appDark)),
      child: const MaterialApp(home: SplashScreen()),
    ));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('app dark mode on: dark facet-fill loader on the dark background, even with the phone in light mode', (tester) async {
    await pumpSplash(tester, appDark: true);
    expect(tester.widget<FacetFillLoader>(find.byType(FacetFillLoader)).dark, isTrue);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, LBrand.splashDark);
  });

  testWidgets('app dark mode off: light facet-fill loader, even with the phone in dark mode', (tester) async {
    await pumpSplash(tester, appDark: false, phone: Brightness.dark);
    expect(tester.widget<FacetFillLoader>(find.byType(FacetFillLoader)).dark, isFalse);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, LBrand.splashLight);
  });

  testWidgets('the logo tile on Welcome follows the app dark mode too', (tester) async {
    for (final dark in [false, true]) {
      await tester.pumpWidget(AppearanceScope(
        controller: AppearanceController(initial: Appearance(dark: dark)),
        child: const MaterialApp(home: Center(child: LuminaLogo())),
      ));
      expect(shownLogo(tester), dark ? LBrand.markDarkAsset : LBrand.markAsset);
    }
  });

  testWidgets('the message sits under the loader and the loader keeps looping', (tester) async {
    await tester.pumpWidget(AppearanceScope(
      controller: AppearanceController(),
      child: const MaterialApp(home: SplashScreen(message: 'Loading your profile…')),
    ));
    await tester.pump(const Duration(seconds: 5)); // past one 3.4 s cycle
    final loader = tester.getCenter(find.byType(FacetFillLoader));
    final message = tester.getTopLeft(find.text('Loading your profile…'));
    expect(message.dy - loader.dy, closeTo(SplashScreen.messageOffset, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('with reduced motion the loaders show the still logo', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const MaterialApp(home: Row(children: [FacetFillLoader(), TwinkleMark()])),
    ));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('the app stays on the loading screen until the logo is fully built once', (tester) async {
    final controller = AppController(backend: DemoBackend(loadCatalog()), ai: HybridAi(hostApi: FakeHost()), clock: () => testNow);
    await tester.pumpWidget(LuminaApp(controller: controller, googleFonts: false));

    await tester.pump(FacetFillLoader.logoBuilt - const Duration(milliseconds: 200));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.text('Continue with email'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300)); // logo built: leave
    await tester.pump(const Duration(seconds: 1)); // screen cross-fade
    expect(find.text('Continue with email'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });
}
