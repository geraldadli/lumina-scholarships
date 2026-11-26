import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'appearance.dart';
import 'device_frame.dart';

/// Gives every screen access to the look settings (and the button that opens the panel).
class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({super.key, required AppearanceController controller, required super.child})
      : super(notifier: controller);

  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;

  static AppearanceController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
}

/// Opens the Customize panel from a screen of the app: beside the phone in the web demo,
/// otherwise as a bottom sheet, which the Android back button closes.
void openCustomize(BuildContext context) {
  if (context.findAncestorWidgetOfExactType<DeviceFrame>() != null) {
    AppearanceScope.read(context).openPanel();
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Not dimmed, so changes can be seen on the screen behind.
    barrierColor: Colors.transparent,
    builder: (sheet) => SizedBox(
      height: math.min(MediaQuery.sizeOf(sheet).height * 0.62, 560),
      child: CustomizePanel(docked: false, onClose: () => Navigator.of(sheet).pop()),
    ),
  );
}

/// Docks the Customize panel to the right of the web demo, so changes preview live.
class CustomizeHost extends StatelessWidget {
  const CustomizeHost({super.key, required this.child});

  final Widget child;

  static const _dockWidth = 340.0;

  @override
  Widget build(BuildContext context) {
    final a = AppearanceScope.of(context);
    final open = a.panelOpen;
    return LayoutBuilder(
      builder: (context, box) => Stack(
        children: [
          // The app stays in the same place in the tree, so opening the panel keeps its state.
          Positioned(left: 0, top: 0, bottom: 0, right: open ? _dockWidth : 0, child: child),
          if (open)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: _dockWidth,
              child: CustomizePanel(docked: true, onClose: a.closePanel),
            )
          else
            Positioned(right: 0, top: box.maxHeight * 0.42, child: _EdgeTab(onTap: a.openPanel)),
        ],
      ),
    );
  }
}

class _EdgeTab extends StatelessWidget {
  const _EdgeTab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        // Its own node, so screen readers announce just this button.
        container: true,
        button: true,
        label: 'Customize look',
        child: Material(
          color: LColors.primary,
          elevation: 3,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(L.r(12))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 52,
              child: Icon(Icons.palette_outlined, size: 20, color: LColors.bg),
            ),
          ),
        ),
      );
}

class CustomizePanel extends StatelessWidget {
  const CustomizePanel({super.key, required this.docked, required this.onClose});

  final bool docked;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final a = AppearanceScope.of(context);
    final v = a.value;

    Widget choices<T>(String title, List<T> values, T selected, String Function(T) label, ValueChanged<T> pick) =>
        _Group(
          title: title,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in values)
                LChip(label: label(option), selected: option == selected, onTap: () => pick(option)),
            ],
          ),
        );

    Widget toggle(String title, String hint, bool value, ValueChanged<bool> set) => Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: ts(15, weight: FontWeight.w600)),
                  Text(hint, style: ts(13, color: LColors.text2, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LToggle(value: value, semanticLabel: title, onChanged: set),
          ],
        );

    return Material(
      color: LColors.white,
      elevation: 12,
      shape: docked
          ? Border(left: BorderSide(color: LColors.line))
          : RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(L.r(22)))),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Customize look', style: ts(19, weight: FontWeight.w700))),
                  // No tooltip: the panel sits outside the navigator, which hosts tooltips.
                  Semantics(
                    button: true,
                    label: 'Close customize panel',
                    child: LIconButton(icon: Icons.close_rounded, onPressed: onClose),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: LColors.soft),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Group(
                    title: 'Colour theme',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        for (final accent in AccentPreset.values)
                          _Swatch(
                            accent: accent,
                            selected: accent == v.accent,
                            onTap: () => a.update(v.copyWith(accent: accent)),
                          ),
                      ],
                    ),
                  ),
                  choices('Text size', TextSize.values, v.textSize, (t) => t.label,
                      (t) => a.update(v.copyWith(textSize: t))),
                  choices('Font', AppFont.values, v.font, (f) => f.label, (f) => a.update(v.copyWith(font: f))),
                  choices('Spacing', Spacing.values, v.spacing, (s) => s.label,
                      (s) => a.update(v.copyWith(spacing: s))),
                  choices('Corners', Corners.values, v.corners, (c) => c.label,
                      (c) => a.update(v.copyWith(corners: c))),
                  toggle('Dark mode', 'Light text on a dark background.', v.dark,
                      (x) => a.update(v.copyWith(dark: x))),
                  const SizedBox(height: 16),
                  toggle('High contrast', 'Darker text and stronger borders.', v.highContrast,
                      (x) => a.update(v.copyWith(highContrast: x))),
                  const SizedBox(height: 24),
                  const _CopyButton(),
                  const SizedBox(height: 8),
                  LButton(
                    label: 'Reset to default',
                    kind: LButtonKind.ghost,
                    height: 44,
                    onPressed: v == const Appearance() ? null : a.reset,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Changes apply right away and are remembered on this device.',
                    textAlign: TextAlign.center,
                    style: ts(13, color: LColors.text2, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Copies the current settings, ready to paste as the app's new defaults.
class _CopyButton extends StatefulWidget {
  const _CopyButton();

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => LButton(
        label: _copied ? 'Copied' : 'Copy settings',
        icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
        kind: LButtonKind.secondary,
        height: 46,
        onPressed: () async {
          final json = const JsonEncoder.withIndent('  ').convert(AppearanceScope.read(context).value.toJson());
          await Clipboard.setData(ClipboardData(text: json));
          if (mounted) setState(() => _copied = true);
        },
      );
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [Text(title, style: ts(15, weight: FontWeight.w700)), child],
        ),
      );
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.accent, required this.selected, required this.onTap});

  final AccentPreset accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: accent.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 84,
            child: Column(
              spacing: 6,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Color(accent.primary),
                    shape: BoxShape.circle,
                    border: Border.all(color: selected ? LColors.ink : LColors.line, width: selected ? 3 : 1),
                  ),
                  child: selected ? const Icon(Icons.check_rounded, color: Color(0xFFFFFFFF), size: 22) : null,
                ),
                ExcludeSemantics(
                  child: Text(
                    accent.label,
                    textAlign: TextAlign.center,
                    style: ts(12, weight: selected ? FontWeight.w700 : FontWeight.w500, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
