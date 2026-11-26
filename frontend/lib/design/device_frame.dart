/// The web demo: the Android app inside a drawn phone. Real phones never see this.
library;

import 'dart:ui' show PointerDeviceKind;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/loading.dart';

/// A phone with an Android status bar and gesture bar. [child] is laid out as on a
/// 390 x 844 screen, and the whole phone shrinks to fit a smaller window.
class DeviceFrame extends StatelessWidget {
  const DeviceFrame({super.key, required this.child});

  final Widget child;

  /// Narrower windows (a phone's own browser) show the app full screen instead.
  static const minWindowWidth = 600.0;

  static const screen = Size(390, 844);
  static const statusBar = 36.0;
  static const gestureBar = 22.0;
  static const _bezel = 11.0;

  @override
  Widget build(BuildContext context) {
    const insets = EdgeInsets.only(top: statusBar, bottom: gestureBar);
    final theme = Theme.of(context);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.all(_bezel),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0D10),
          borderRadius: BorderRadius.circular(52),
          border: Border.all(color: const Color(0xFF4A525C), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x4010161D), blurRadius: 40, offset: Offset(0, 18))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(42),
          child: SizedBox.fromSize(
            size: screen,
            child: Stack(
              children: [
                Positioned.fill(
                  child: MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(size: screen, padding: insets, viewPadding: insets, viewInsets: EdgeInsets.zero),
                    // Behave like Android, not like the desktop the browser runs on.
                    child: Theme(
                      data: theme.copyWith(platform: TargetPlatform.android, visualDensity: VisualDensity.standard),
                      child: ScrollConfiguration(
                        // Dragging with the mouse scrolls, like a finger would.
                        behavior: const MaterialScrollBehavior()
                            .copyWith(dragDevices: PointerDeviceKind.values.toSet(), scrollbars: false),
                        child: child,
                      ),
                    ),
                  ),
                ),
                const Positioned(top: 0, left: 0, right: 0, height: statusBar, child: _StatusBar()),
                const Positioned(bottom: 0, left: 0, right: 0, height: gestureBar, child: _GestureBar()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 0, 22, 0),
                child: Row(
                  children: [
                    Text('10:00', textScaler: TextScaler.noScaling, style: ts(14, weight: FontWeight.w600)),
                    const Spacer(),
                    for (final icon in const [
                      Icons.wifi_rounded,
                      Icons.signal_cellular_alt_rounded,
                      Icons.battery_full_rounded,
                    ]) ...[const SizedBox(width: 4), Icon(icon, size: 16, color: LColors.ink)],
                  ],
                ),
              ),
              // Front camera.
              const Align(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0xFF0B0D10), shape: BoxShape.circle),
                  child: SizedBox.square(dimension: 14),
                ),
              ),
            ],
          ),
        ),
      );
}

class _GestureBar extends StatelessWidget {
  const _GestureBar();

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Center(
          child: Container(
            width: 120,
            height: 4,
            decoration: BoxDecoration(color: LColors.ink.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
          ),
        ),
      );
}

/// The page around the phone: what this is, next to the app itself.
class DemoStage extends StatelessWidget {
  const DemoStage({super.key, required this.child});

  /// The phone.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? const Color(0xFF06090D) : const Color(0xFFE6ECF3),
      child: LayoutBuilder(
        builder: (context, box) {
          final about = box.maxWidth >= 860;
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (about) ...[const SizedBox(width: 300, child: _About()), const SizedBox(width: 56)],
              // Flexible, so the phone shrinks instead of overflowing.
              Flexible(child: Padding(padding: const EdgeInsets.all(20), child: child)),
            ],
          );
        },
      ),
    );
  }
}

class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 14,
          children: [
            const LuminaLogo(size: 60),
            Text('Lumina for Android', style: ts(30, weight: FontWeight.w700, spacing: -0.6, height: 1.2)),
            Text(
              'A live demo of the app. Click and scroll inside the phone as you would on a real one.',
              style: ts(16, color: LColors.text2, height: 1.5),
            ),
            Text(
              'This demo uses sample data and starts over when the page reloads. '
              'AI answers need the Android app.',
              style: ts(14, color: LColors.text2, height: 1.5),
            ),
          ],
        ),
      );
}
