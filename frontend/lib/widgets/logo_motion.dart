import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Animated versions of the Lumina logo, from the "Lumina Loaders" design:
/// - [FacetFillLoader] (1b): the app loading screen.
/// - [TwinkleMark] (1d): the Ask AI "assistant is answering" indicator.
///
/// The logo is drawn from its five shapes (same points as assets/brand/lumina_mark.svg), so each
/// shape can move on its own. Timings and keyframes are copied from the design. When the device
/// asks for reduced motion, both show the plain logo.

class _Shape {
  const _Shape(this.points, this.order);

  /// Points on the 100 x 100 grid.
  final List<Offset> points;

  /// Position in the facet-fill sequence (0 = first).
  final int order;

  Path get path => Path()..addPolygon(points, true);
}

List<Offset> _pts(String s) => [
      for (final p in s.split(' '))
        Offset(double.parse(p.split(',')[0]), double.parse(p.split(',')[1])),
    ];

/// Star, cap top, cap front, band left, band right: the order of the colour lists.
final _shapes = [
  _Shape(_pts('50,4 53,11 60,14 53,17 50,24 47,17 40,14 47,11'), 4),
  _Shape(_pts('10,46 50,30 90,46'), 3),
  _Shape(_pts('10,46 50,62 90,46'), 2),
  _Shape(_pts('26,54 50,64 50,82 26,72'), 0),
  _Shape(_pts('50,64 74,54 74,72 50,82'), 1),
];
const _star = 0;
const _top = 1;

/// Centre of the star's bounding box: the origin for its pop, twinkle and glow.
const _starCentre = Offset(50, 14);

const _lightColours = [Color(0xFF5E8FC6), Color(0xFF5E8FC6), Color(0xFF2F4660), Color(0xFF233447), Color(0xFF17222E)];
const _darkColours = [Color(0xFFE0EEFC), Color(0xFFE0EEFC), Color(0xFFA9CBF2), Color(0xFF5E8FC6), Color(0xFF36557A)];

/// CSS-style keyframes: (offset 0..1, value), eased per segment like `animation-timing-function`.
class _Keys {
  const _Keys(this.frames, [this.curve = Curves.easeInOut]);

  final List<(double, double)> frames;
  final Curve curve;

  double at(double t) {
    if (t <= frames.first.$1) return frames.first.$2;
    for (var i = 1; i < frames.length; i++) {
      final (t1, v1) = frames[i];
      if (t <= t1) {
        final (t0, v0) = frames[i - 1];
        final f = t1 == t0 ? 1.0 : curve.transform((t - t0) / (t1 - t0));
        return v0 + (v1 - v0) * f;
      }
    }
    return frames.last.$2;
  }
}

/// Runs a clock from when the widget appears, unless the device asks for reduced motion.
mixin _Clock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  final elapsed = ValueNotifier(Duration.zero);
  late final Ticker _ticker = createTicker((d) => elapsed.value = d);
  bool still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    elapsed.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// 1b: app loading, facet fill
// ---------------------------------------------------------------------------

/// The shapes fill in order, hold, then fade out in the same order, and repeat. A faint outline
/// of the logo stays visible, so the screen is never empty.
class FacetFillLoader extends StatefulWidget {
  const FacetFillLoader({super.key, this.size = 120, this.dark = false});

  final double size;
  final bool dark;

  /// One full cycle and the gap between shapes, from the design.
  static const cycle = Duration(milliseconds: 3400);
  static const stagger = Duration(milliseconds: 220);

  /// When the first cycle has built the whole logo: the star (last, 4 x [stagger] in) has filled,
  /// popped and its glow has faded (46% into its cycle). The best frame to leave the loading
  /// screen on, before the shapes start fading out again.
  static final logoBuilt = stagger * 4 + cycle * .46;

  @override
  State<FacetFillLoader> createState() => _FacetFillLoaderState();
}

class _FacetFillLoaderState extends State<FacetFillLoader> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: still
              ? _StaticLogoPainter(widget.dark ? _darkColours : _lightColours)
              : _FacetFillPainter(elapsed, widget.dark),
        ),
      );
}

// @keyframes lmLoop (outline draws in, fills, holds, fades out)
const _dash = _Keys([(0, 1), (.14, 0), (1, 0)]);
const _fill = _Keys([(0, 0), (.14, 0), (.26, 1), (.80, 1), (.92, 0), (1, 0)]);
const _strokeOpacity = _Keys([(0, 1), (.14, 1), (.26, 0), (1, 0)]);
// @keyframes lmPopLoop / lmGlowLoop (the star, after the other shapes)
const _pop = _Keys([(0, 1), (.22, 1), (.30, 1.22), (.40, 1), (1, 1)]);
const _glowLoopOpacity = _Keys([(0, 0), (.20, 0), (.26, .45), (.46, 0), (1, 0)], Curves.easeOut);
const _glowLoopScale = _Keys([(0, .2), (.20, .2), (.46, 1.7), (1, 1.7)], Curves.easeOut);

class _FacetFillPainter extends CustomPainter {
  _FacetFillPainter(this.elapsed, this.dark) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final colours = dark ? _darkColours : _lightColours;
    final ms = elapsed.value.inMicroseconds / 1000;
    final cycle = FacetFillLoader.cycle.inMilliseconds;
    // Local position in a shape's cycle; before its delay it holds the first keyframe.
    double local(int order) {
      final t = ms - order * FacetFillLoader.stagger.inMilliseconds;
      return t <= 0 ? 0 : (t % cycle) / cycle;
    }

    canvas
      ..save()
      ..scale(size.width / 100);

    // The faint outline of the whole logo.
    for (var i = 0; i < _shapes.length; i++) {
      canvas.drawPath(_shapes[i].path, Paint()..color = colours[i].withValues(alpha: dark ? .13 : .10));
    }

    for (var i = 0; i < _shapes.length; i++) {
      final shape = _shapes[i];
      final t = local(shape.order);
      final colour = colours[i];
      canvas.save();
      if (i == _star) {
        final glowScale = _glowLoopScale.at(t);
        final glowOpacity = _glowLoopOpacity.at(t);
        if (glowOpacity > 0) {
          canvas.drawCircle(_starCentre, 14 * glowScale, Paint()..color = colour.withValues(alpha: glowOpacity));
        }
        final pop = _pop.at(t);
        canvas
          ..translate(_starCentre.dx, _starCentre.dy)
          ..scale(pop)
          ..translate(-_starCentre.dx, -_starCentre.dy);
      }
      final path = shape.path;
      final fill = _fill.at(t);
      if (fill > 0) canvas.drawPath(path, Paint()..color = colour.withValues(alpha: fill));
      final drawn = 1 - _dash.at(t);
      final strokeOpacity = _strokeOpacity.at(t);
      if (drawn > 0 && strokeOpacity > 0) {
        canvas.drawPath(
          _trim(path, drawn),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.butt
            ..color = colour.withValues(alpha: strokeOpacity),
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  /// The first [fraction] of the outline, like an SVG stroke-dashoffset with pathLength 1.
  static Path _trim(Path path, double fraction) {
    final out = Path();
    for (final m in path.computeMetrics()) {
      out.addPath(m.extractPath(0, m.length * fraction.clamp(0, 1)), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_FacetFillPainter old) => old.dark != dark || old.elapsed != elapsed;
}

// ---------------------------------------------------------------------------
// 1d: AI assistant, twinkling star
// ---------------------------------------------------------------------------

/// The star twinkles above the cap (lifts, turns and shrinks), a soft glow pulses behind it and
/// the cap top breathes. Shown next to the Ask AI status line while an answer is written.
class TwinkleMark extends StatefulWidget {
  const TwinkleMark({super.key, this.size = 36, this.dark = false});

  final double size;
  final bool dark;

  static const period = Duration(milliseconds: 1600);

  @override
  State<TwinkleMark> createState() => _TwinkleMarkState();
}

class _TwinkleMarkState extends State<TwinkleMark> with SingleTickerProviderStateMixin, _Clock {
  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: still
              ? _StaticLogoPainter(widget.dark ? _darkColours : _lightColours)
              : _TwinklePainter(elapsed, widget.dark),
        ),
      );
}

// @keyframes lmTwinkle / lmGlowPulse / lmBreath
const _twinkleLift = _Keys([(0, 0), (.5, -4), (1, 0)]);
const _twinkleTurn = _Keys([(0, 0), (.5, 45), (1, 90)]);
const _twinkleScale = _Keys([(0, 1), (.5, .72), (1, 1)]);
const _pulseOpacity = _Keys([(0, 0), (.5, .32), (1, 0)]);
const _pulseScale = _Keys([(0, .4), (.5, 1.1), (1, .4)]);
const _breath = _Keys([(0, 1), (.5, .7), (1, 1)]);

class _TwinklePainter extends CustomPainter {
  _TwinklePainter(this.elapsed, this.dark) : super(repaint: elapsed);

  final ValueListenable<Duration> elapsed;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final colours = dark ? _darkColours : _lightColours;
    final period = TwinkleMark.period.inMicroseconds;
    final t = (elapsed.value.inMicroseconds % period) / period;

    canvas
      ..save()
      ..scale(size.width / 100);

    final glow = _pulseOpacity.at(t);
    if (glow > 0) {
      canvas.drawCircle(_starCentre, 14 * _pulseScale.at(t), Paint()..color = colours[_star].withValues(alpha: glow));
    }
    for (var i = 0; i < _shapes.length; i++) {
      final alpha = i == _top ? _breath.at(t) : 1.0;
      if (i == _star) {
        canvas
          ..save()
          ..translate(_starCentre.dx, _starCentre.dy + _twinkleLift.at(t))
          ..rotate(_twinkleTurn.at(t) * math.pi / 180)
          ..scale(_twinkleScale.at(t))
          ..translate(-_starCentre.dx, -_starCentre.dy)
          ..drawPath(_shapes[i].path, Paint()..color = colours[i])
          ..restore();
      } else {
        canvas.drawPath(_shapes[i].path, Paint()..color = colours[i].withValues(alpha: alpha));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TwinklePainter old) => old.dark != dark || old.elapsed != elapsed;
}

/// The plain logo, for reduced motion.
class _StaticLogoPainter extends CustomPainter {
  const _StaticLogoPainter(this.colours);

  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / 100);
    for (var i = 0; i < _shapes.length; i++) {
      canvas.drawPath(_shapes[i].path, Paint()..color = colours[i]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaticLogoPainter old) => old.colours != colours;
}
