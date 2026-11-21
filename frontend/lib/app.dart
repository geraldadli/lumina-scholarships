import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'screens/auth_screens.dart';
import 'screens/home_shell.dart';
import 'screens/profile_form.dart';
import 'state/app_controller.dart';
import 'state/app_scope.dart';
import 'theme.dart';
import 'widgets/common.dart';

class LuminaApp extends StatefulWidget {
  const LuminaApp({
    super.key,
    required this.controller,
    this.splashDuration = const Duration(milliseconds: 1200),
    this.googleFonts = true,
  });

  final AppController controller;
  final Duration splashDuration;
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

  @override
  void initState() {
    super.initState();
    widget.controller
      ..start()
      ..addListener(_onChange);
    _notices = widget.controller.notices.listen((msg) {
      final m = _messenger.currentState;
      if (m != null) showToastOn(m, msg, icon: Icons.error_outline_rounded);
    });
    if (widget.splashDuration == Duration.zero) {
      _splashDone = true;
    } else {
      _splash = Timer(widget.splashDuration, () => setState(() => _splashDone = true));
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

  @override
  void dispose() {
    _splash?.cancel();
    _notices?.cancel();
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
        controller: widget.controller,
        child: MaterialApp(
          title: 'Lumina',
          debugShowCheckedModeBanner: false,
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
          theme: buildLuminaTheme(googleFonts: widget.googleFonts),
          home: _RootGate(splashDone: _splashDone),
        ),
      );
}

/// Splash → Welcome (signed out) → Onboarding (no profile yet) → tabs.
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
      screen = const SplashScreen(key: ValueKey('loading'));
    } else if (c.profile == null || !c.profile!.onboardingCompleted) {
      screen = OnboardingScreen(key: ValueKey('onboarding-${c.user!.uid}'));
    } else {
      screen = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: screen);
  }
}
