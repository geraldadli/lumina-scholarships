import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'common.dart';
import 'layout.dart';

class LuminaLogo extends StatelessWidget {
  const LuminaLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: LColors.primary, borderRadius: BorderRadius.circular(L.r(size * 0.29))),
        child: Icon(Icons.school_rounded, size: size * 0.52, color: LColors.bg),
      );
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

/// The full-screen loading screen: shown at start-up and while the profile loads.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message = 'Getting things ready…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Pulse(builder: (_, t) => Transform.scale(scale: 1 + 0.06 * t, child: const LuminaLogo())),
              const SizedBox(height: 22),
              Text('Lumina', style: ts(32, weight: FontWeight.w700, spacing: -0.6)),
              const SizedBox(height: 6),
              Text('Scholarships, matched to you', textAlign: TextAlign.center, style: ts(16, color: LColors.text2)),
              const SizedBox(height: 32),
              SizedBox(
                width: 180,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: still ? 0.5 : null,
                    minHeight: 5,
                    color: LColors.primary,
                    backgroundColor: LColors.soft,
                    semanticsLabel: 'Loading',
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(message, textAlign: TextAlign.center, style: ts(14, color: LColors.text2)),
            ],
          ),
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
