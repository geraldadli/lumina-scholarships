import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Dark mode on/off as one calm fade: the old theme dissolves into the new one, dimming
/// slightly on the way to dark. No flashes or flicker, so it is easy on the eyes.
///
/// How it works: just before the colours change, [capture] takes a picture of the screen.
/// After the change the new theme is already underneath; the old picture is drawn on top and
/// faded out. Skipped when the device asks for reduced motion.
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
    duration: const Duration(milliseconds: 450),
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
                  painter: _FadePainter(
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

class _FadePainter extends CustomPainter {
  _FadePainter({required this.image, required this.progress, required this.toDark}) : super(repaint: progress);

  final ui.Image image;
  final Animation<double> progress;
  final bool toDark;

  @override
  void paint(Canvas canvas, Size size) {
    // One smooth curve, no steps: the old screen fades out evenly.
    final t = Curves.easeInOut.transform(progress.value);
    final shown = 1 - t;
    if (shown <= 0) return;
    final rect = Offset.zero & size;

    canvas.saveLayer(rect, Paint()..color = Color.fromRGBO(0, 0, 0, shown));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    // Going dark, the old light screen also dims a little as it fades, so it never looks
    // brighter than the screen it turns into.
    if (toDark) canvas.drawRect(rect, Paint()..color = Color.fromRGBO(0, 0, 0, 0.35 * t));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FadePainter old) => old.image != image || old.toDark != toDark;
}
