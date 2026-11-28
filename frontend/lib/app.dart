import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'design/appearance.dart';
import 'design/customize_panel.dart';
import 'design/theme_sweep.dart';
import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/profile_form.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/loading.dart';
import 'widgets/logo_motion.dart';
import 'widgets/night_mode.dart';
import 'widgets/motion.dart';

class LuminaApp extends StatefulWidget {
  const LuminaApp({
    super.key,
    required this.controller,
    this.appearance,
    this.splashDuration,
    this.googleFonts = true,
  });

  final AppController controller;

  /// The customizable look. Without one the default look is used and nothing is remembered.
  final AppearanceController? appearance;
  /// How long the loading screen shows at least. By default, until its animation has built the
  /// whole logo once ([FacetFillLoader.logoBuilt], about 2.4 s), so everyone sees it complete;
  /// with reduced motion the still logo needs no wait beyond a short moment.
  final Duration? splashDuration;
  final bool googleFonts;

  @override
  State<LuminaApp> createState() => _LuminaAppState();
}

class _LuminaAppState extends State<LuminaApp> {
  final _navigator = GlobalKey<NavigatorState>();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<String>? _notices;
  bool _splashDone = false;
  Timer? _splash;
  String? _lastUid;
  late final AppearanceController _appearance = widget.appearance ?? AppearanceController();
  late Appearance _look = _appearance.value;
  final _sweep = GlobalKey<ThemeSweepState>();

  @override
  void initState() {
    super.initState();
    applyAppearance(_look);
    syncNightMode(_look.dark);
    _appearance.addListener(_onAppearance);
    widget.controller
      ..start()
      ..addListener(_onChange);
    _notices = widget.controller.notices.listen((msg) {
      final m = _messenger.currentState;
      if (m != null) showToastOn(m, msg, icon: Icons.error_outline_rounded);
    });
    final reduceMotion = WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    final minimum = widget.splashDuration ??
        (reduceMotion ? const Duration(milliseconds: 600) : FacetFillLoader.logoBuilt);
    if (minimum == Duration.zero) {
      _splashDone = true;
    } else {
      _splash = Timer(minimum, () => setState(() => _splashDone = true));
    }
  }

  /// On sign-in / sign-out, drop any pushed pages so the gate shows the right root screen.
  void _onChange() {
    final uid = widget.controller.user?.uid;
    if (uid != _lastUid) {
      _lastUid = uid;
      _navigator.currentState?.popUntil((r) => r.isFirst);
    }
  }

  /// A new look: swap the colours and sizes, then rebuild every widget that is on screen.
  /// Colours are read directly (not through the theme), so nothing would rebuild by itself.
  void _onAppearance() {
    if (_appearance.value == _look) return;
    final next = _appearance.value;
    // Dark mode on/off fades smoothly into the new theme; other changes apply at once.
    if (next.dark != _look.dark) {
      _sweep.currentState?.capture(toDark: next.dark);
      syncNightMode(next.dark);
    }
    setState(() {
      _look = _appearance.value;
      applyAppearance(_look);
    });
    void rebuild(Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  void dispose() {
    _splash?.cancel();
    _notices?.cancel();
    widget.controller.removeListener(_onChange);
    _appearance.removeListener(_onAppearance);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppearanceScope(
        controller: _appearance,
        child: AppScope(
          controller: widget.controller,
          child: MaterialApp(
            title: 'Lumina',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navigator,
            scaffoldMessengerKey: _messenger,
            theme: buildLuminaTheme(appearance: _look, googleFonts: widget.googleFonts),
            builder: (context, child) {
              // The "Text size" setting multiplies the device's own text size.
              final media = MediaQuery.of(context);
              final scale = media.textScaler.scale(100) / 100 * _look.textSize.scale;
              return MediaQuery(
                data: media.copyWith(textScaler: TextScaler.linear(scale)),
                child: ThemeSweep(key: _sweep, child: child!),
              );
            },
            home: _RootGate(splashDone: _splashDone),
          ),
        ),
      );
}

/// Loading screen → Welcome (signed out) → Onboarding (no profile yet) → the app.
class _RootGate extends StatelessWidget {
  const _RootGate({required this.splashDone});

  final bool splashDone;

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final Widget screen;
    if (!splashDone || !c.authResolved) {
      screen = const SplashScreen(key: ValueKey('splash'));
    } else if (c.user == null) {
      screen = const WelcomeScreen(key: ValueKey('welcome'));
    } else if (!c.profileLoaded) {
      screen = const SplashScreen(key: ValueKey('splash'), message: 'Loading your profile…');
    } else if (c.profile == null || !c.profile!.onboardingCompleted) {
      screen = OnboardingScreen(key: ValueKey('onboarding-${c.user!.uid}'));
    } else {
      screen = const HomeShell(key: ValueKey('home'));
    }
    // The background stays put underneath while two screens cross-fade.
    return ColoredBox(
      color: LColors.bg,
      child: AnimatedSwitcher(
        duration: LMotion.duration,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: screenFade,
        child: screen,
      ),
    );
  }
}
