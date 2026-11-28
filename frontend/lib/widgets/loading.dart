import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../design/customize_panel.dart';
import '../theme.dart';
import 'common.dart';
import 'layout.dart';
import 'logo_motion.dart';

/// The Lumina logo (Lumina_Logo_2a, "Cap & spark") on its tile: the light version normally,
/// the dark version when Lumina's dark mode is on.
class LuminaLogo extends StatelessWidget {
  const LuminaLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = appDarkMode(context);
    return Semantics(
      label: 'Lumina',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.16),
        decoration: BoxDecoration(
          color: dark ? LBrand.tileDark : LBrand.tile,
          borderRadius: BorderRadius.circular(size * 0.25),
          border: Border.all(color: dark ? LBrand.tileEdgeDark : LBrand.tileEdge),
        ),
        child: SvgPicture.asset(dark ? LBrand.markDarkAsset : LBrand.markAsset),
      ),
    );
  }
}

/// Lumina's own dark mode setting (Profile > Dark mode); the phone's setting if there is none.
bool appDarkMode(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<AppearanceScope>()?.notifier?.value.dark ??
    MediaQuery.platformBrightnessOf(context) == Brightness.dark;

/// "Lumina" in Manrope, as next to the logo in the design.
class LuminaWordmark extends StatelessWidget {
  const LuminaWordmark({super.key, this.size = 28});

  final double size;

  @override
  Widget build(BuildContext context) => Text(
        'Lumina',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: size,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700)],
          letterSpacing: -0.01 * size,
          color: LColors.ink,
        ),
      );
}

/// Brand colours and files from Lumina_Logo_2a. They match the Android start-up screen
/// (android/app/src/main/res/values*/colors.xml), so the hand-off to Flutter is invisible.
abstract final class LBrand {
  static const markAsset = 'assets/brand/lumina_mark.svg';
  static const markDarkAsset = 'assets/brand/lumina_mark_dark.svg';
  static const tile = Color(0xFFF7F9FB);
  static const tileEdge = Color(0xFFCBD7E3);
  static const tileDark = Color(0xFF111820);
  static const tileEdgeDark = Color(0xFF3A4756);
  static const splashLight = Color(0xFFF7F9FB);
  static const splashDark = Color(0xFF111820);
}

/// Repeats a 0→1→0 animation, or holds still when the device asks for less motion.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.builder});

  final Widget Function(BuildContext context, double t) builder;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => widget.builder(context, Curves.easeInOut.transform(_controller.value)),
      );
}

/// The full-screen loading screen ("Lumina Loaders" 1b): the logo's shapes fill in one after
/// another and fade out again, in a loop, over a faint outline of the logo. Dark version when
/// Lumina's dark mode is on. The Android start-up screen before it is told the same setting
/// (see syncNightMode), so the two look like one screen. A [message] (e.g. while the profile
/// loads) sits under the logo without moving it.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  /// The logo's size, and the gap from the screen centre to the message, from the design.
  static const markSize = 120.0;
  static const messageOffset = 92.0;

  @override
  Widget build(BuildContext context) {
    final dark = appDarkMode(context);
    final message = this.message;
    return Scaffold(
      backgroundColor: dark ? LBrand.splashDark : LBrand.splashLight,
      body: LayoutBuilder(
        builder: (context, box) => Stack(
          children: [
            Center(
              child: Semantics(
                label: 'Lumina is loading',
                child: FacetFillLoader(size: markSize, dark: dark),
              ),
            ),
            if (message != null)
              Positioned(
                left: 24,
                right: 24,
                top: box.maxHeight / 2 + messageOffset,
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: dark ? const Color(0xFFA9CBF2) : const Color(0xFF2F4660)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Grey placeholder cards in the shape of the real ones, while the catalog loads.
class ScholarshipSkeletons extends StatelessWidget {
  const ScholarshipSkeletons({super.key, this.count = 3});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading scholarships',
        child: _Pulse(
          builder: (context, t) => Opacity(
            opacity: 0.55 + 0.45 * t,
            child: CardGrid(children: [for (var i = 0; i < count; i++) const _SkeletonCard()]),
          ),
        ),
      );
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          widthFactor: widthFactor,
          alignment: Alignment.centerLeft,
          child: Container(
            height: height,
            decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(L.r(6))),
          ),
        );
    return LCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [bar(0.8, 20), bar(0.55, 14), const SizedBox(height: 4), bar(0.45, 14), bar(0.6, 14), bar(0.3, 26)],
      ),
    );
  }
}
