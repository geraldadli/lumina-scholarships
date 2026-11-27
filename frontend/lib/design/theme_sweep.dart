import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Dark mode on/off like a light losing or getting power.
///
/// - Turning dark mode **on**: the light screen flickers, dims and dies out into the dark theme.
/// - Turning it **off**: the dark screen stutters as the light flickers on, then settles bright.
///
/// How it works: just before the colours change, [capture] takes a picture of the screen.
/// After the change the new theme is already underneath; the old picture is drawn on top and
/// flickered / faded away. Skipped when the device asks for reduced motion.
class ThemeSweep extends StatefulWidget {
  const ThemeSweep({super.key, required this.child});

  final Widget child;

  @override
  ThemeSweepState createState() => ThemeSweepState();
}

class ThemeSweepState extends State<ThemeSweep> with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _clear();
    });
  ui.Image? _old;
  bool _toDark = true;

  /// Call right before the colours change. [toDark] is true when dark mode is being turned on.
  void capture({required bool toDark}) {
    if (!mounted || MediaQuery.maybeDisableAnimationsOf(context) == true) return;
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary || !box.hasSize || box.debugNeedsPaintSafe) return;
    try {
      final image = box.toImageSync(pixelRatio: MediaQuery.devicePixelRatioOf(context));
      _old?.dispose();
      setState(() {
        _old = image;
        _toDark = toDark;
      });
      _anim.forward(from: 0);
    } on Object catch (e) {
      // No picture (e.g. a renderer without image support): the theme just switches at once.
      debugPrint('Lumina: theme transition skipped: $e');
    }
  }

  void _clear() {
    if (_old == null) return;
    final old = _old;
    setState(() => _old = null);
    old?.dispose();
  }

  @override
  void dispose() {
    _anim.dispose();
    _old?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.passthrough,
        children: [
          RepaintBoundary(key: _boundary, child: widget.child),
          if (_old != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _PowerPainter(
                    image: _old!,
                    progress: _anim,
                    toDark: _toDark,
                  ),
                ),
              ),
            ),
        ],
      );
}

extension on RenderRepaintBoundary {
  /// `debugNeedsPaint` only exists in debug builds; in release a laid-out boundary is painted.
  bool get debugNeedsPaintSafe {
    var needs = false;
    assert(() {
      needs = debugNeedsPaint;
      return true;
    }());
    return needs;
  }
}

/// One step of the flicker: hold or move to [value] over [weight] parts of the animation.
TweenSequenceItem<double> _to(double from, double to, double weight, [Curve curve = Curves.linear]) =>
    TweenSequenceItem(tween: Tween(begin: from, end: to).chain(CurveTween(curve: curve)), weight: weight);

/// How much of the old screen is still showing (1 = all of it).
final _powerDown = TweenSequence<double>([
  _to(1, 1, 8), // still on
  _to(1, .35, 4), // first drop
  _to(.35, .95, 4), // catches
  _to(.95, .95, 8),
  _to(.95, .2, 3), // drops harder
  _to(.2, .7, 5), // weak recovery
  _to(.7, .45, 6),
  _to(.45, .8, 3), // last gasp
  _to(.8, 0, 59, Curves.easeInCubic), // dies out
]);

final _powerUp = TweenSequence<double>([
  _to(1, 1, 10), // still dark
  _to(1, .55, 3), // first spark
  _to(.55, 1, 4),
  _to(1, 1, 8),
  _to(1, .3, 3), // brighter spark
  _to(.3, .85, 5),
  _to(.85, .15, 4), // nearly on
  _to(.15, .5, 4),
  _to(.5, 0, 59, Curves.easeOutCubic), // light settles on
]);

/// How dark the old screen has gone as its power fails (0 = not dimmed).
final _dimming = TweenSequence<double>([
  _to(0, 0, 8),
  _to(0, .45, 4),
  _to(.45, .1, 4),
  _to(.1, .15, 8),
  _to(.15, .6, 3),
  _to(.6, .35, 5),
  _to(.35, .55, 9),
  _to(.55, .9, 59, Curves.easeIn),
]);

class _PowerPainter extends CustomPainter {
  _PowerPainter({required this.image, required this.progress, required this.toDark}) : super(repaint: progress);

  final ui.Image image;
  final Animation<double> progress;
  final bool toDark;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value;
    final shown = (toDark ? _powerDown : _powerUp).transform(t).clamp(0.0, 1.0);
    if (shown <= 0) return;
    final rect = Offset.zero & size;

    canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, shown));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (toDark) {
      // The bulb browning out: the old light screen goes dim before it fades.
      final dim = _dimming.transform(t).clamp(0.0, 1.0);
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(0, 0, 0, dim * .8));
    } else {
      // Sparks of light through the dark screen while the bulb warms up.
      final spark = (1 - shown) * (1 - t);
      canvas.drawRect(rect, Paint()..color = Color.fromRGBO(255, 248, 225, spark * .35));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PowerPainter old) => old.image != image || old.toDark != toDark;
}
