/// How the app moves between pages. Change the timing or distance here.
///
/// Pushed screens (details, Ask AI, ...) use the page transition set in `theme.dart`.
/// Switching inside a screen (tabs, onboarding steps, Saved segments) uses [PageSwitch],
/// and the start-up screens use [screenFade].
library;

import 'package:material_ui/material_ui.dart';

abstract final class LMotion {
  static const duration = Duration(milliseconds: 320);

  /// How far a new page slides in, as a share of its width.
  static const slide = 0.08;
}

/// Animates [child] in whenever [page] changes: it fades in while sliding from the side it
/// comes from (right when going forward, left when going back).
///
/// Only the incoming page moves and [child] is never rebuilt from scratch by this widget,
/// so tabs keep their scroll position and typed text.
class PageSwitch extends StatefulWidget {
  const PageSwitch({super.key, required this.page, required this.child});

  /// The position of the current page; its order decides the slide direction.
  final int page;
  final Widget child;

  @override
  State<PageSwitch> createState() => _PageSwitchState();
}

class _PageSwitchState extends State<PageSwitch> with SingleTickerProviderStateMixin {
  // Starts finished: the first page is simply there.
  late final _controller = AnimationController(vsync: this, duration: LMotion.duration, value: 1);
  late final _opacity = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.8, curve: Curves.easeOut));
  late final _movement = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  double _direction = 1;

  @override
  void didUpdateWidget(PageSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.page == oldWidget.page) return;
    _direction = widget.page > oldWidget.page ? 1 : -1;
    // "Remove animations" in the phone's accessibility settings: switch at once.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _opacity.dispose();
    _movement.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRect(
        // Clipped, so a sliding page never draws over the sidebar or a header.
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: _movement.drive(_SlideFrom(this)),
            child: widget.child,
          ),
        ),
      );
}

/// From one side to rest; reads the direction as it stands when the frame is drawn.
class _SlideFrom extends Animatable<Offset> {
  _SlideFrom(this.state);

  final _PageSwitchState state;

  @override
  Offset transform(double t) => Offset(state._direction * LMotion.slide * (1 - t), 0);
}

/// For whole screens replacing each other (loading, welcome, onboarding, home):
/// the new one fades in while growing very slightly.
Widget screenFade(Widget child, Animation<double> animation) => FadeTransition(
      opacity: animation,
      child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(animation), child: child),
    );
