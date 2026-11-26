import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'layout.dart';

enum LButtonKind { primary, secondary, soft, ghost }

/// The app's buttons: solid primary, outlined secondary, tinted soft, and text-only.
class LButton extends StatelessWidget {
  const LButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = LButtonKind.primary,
    this.icon,
    this.trailingIcon,
    this.height = 52,
    this.radius = 14,
    this.fontSize = 15,
    this.leading,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final LButtonKind kind;
  final IconData? icon;
  final IconData? trailingIcon;
  final Widget? leading;

  /// Smallest height; the button grows if large text needs more room.
  final double height;
  final double radius;
  final double fontSize;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, border) = switch (kind) {
      LButtonKind.primary => (LColors.primary, LColors.bg, null),
      LButtonKind.secondary => (LColors.white, LColors.ink, LColors.line),
      LButtonKind.soft => (LColors.soft, LColors.ink, LColors.line),
      LButtonKind.ghost => (Colors.transparent, LColors.text2, null),
    };
    final enabled = onPressed != null && !busy;
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(L.r(radius)),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          hoverColor: kind == LButtonKind.primary ? LColors.primaryHover : LColors.soft,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (busy)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  else ...[
                    if (leading != null) ...[leading!, const SizedBox(width: 10)],
                    if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: ts(fontSize, weight: FontWeight.w600, color: fg, height: 1.25),
                      ),
                    ),
                    if (trailingIcon != null) ...[const SizedBox(width: 6), Icon(trailingIcon, size: 18, color: fg)],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Square outlined icon button (back, share, bookmark, filters).
class LIconButton extends StatelessWidget {
  const LIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.color,
    this.background,
    this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? background;
  final String? tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background ?? LColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(L.r(size * 0.3)),
        side: BorderSide(color: LColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        hoverColor: LColors.soft,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: iconSize, color: color ?? LColors.ink),
              if (badge)
                Positioned(
                  top: size * 0.22,
                  right: size * 0.24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: LColors.primary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

/// Selectable chip used in filters and study goals. Only as wide as its label.
class LChip extends StatelessWidget {
  const LChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? LColors.soft : LColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(L.r(18)),
            side: BorderSide(color: selected ? LColors.primary : LColors.line, width: selected ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // A tick, so "selected" does not depend on colour alone.
                    if (selected) ...[
                      Icon(Icons.check_rounded, size: 16, color: LColors.ink),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(label, style: ts(14, weight: selected ? FontWeight.w700 : FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

/// Small rectangular tag (Urgent, Closed, Verified).
class LTag extends StatelessWidget {
  const LTag(this.label, {super.key, this.strong = false, this.icon});

  final String label;
  final bool strong;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: strong ? LColors.primary : LColors.bg,
          borderRadius: BorderRadius.circular(L.r(7)),
          border: Border.all(color: strong ? LColors.primary : LColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: strong ? LColors.bg : LColors.text2),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(label, style: ts(13, weight: FontWeight.w600, color: strong ? LColors.bg : LColors.text2)),
            ),
          ],
        ),
      );
}

/// Tinted badge ("82% match", "Cloud AI", "Ready").
class LBadge extends StatelessWidget {
  const LBadge(this.label, {super.key, this.icon, this.size = 13});

  final String label;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(L.r(7))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: LColors.ink), const SizedBox(width: 5)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: ts(size, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
}

/// The app's 46x28 toggle.
class LToggle extends StatelessWidget {
  const LToggle({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        label: semanticLabel,
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => onChanged(!value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 28,
              decoration: BoxDecoration(
                color: value ? LColors.primary : LColors.muted.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: value ? LColors.bg : const Color(0xFFFFFFFF),
                    shape: BoxShape.circle,
                    boxShadow: const [BoxShadow(color: Color(0x401F2D3D), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

/// White bordered card.
class LCard extends StatelessWidget {
  const LCard({super.key, required this.child, this.padding, this.onTap, this.color});

  final Widget child;

  /// Defaults to 18 all round, scaled by the "Spacing" setting.
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: color ?? LColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(L.r(16)),
          side: BorderSide(color: LColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: LColors.soft.withValues(alpha: 0.35),
          child: Padding(padding: padding ?? EdgeInsets.all(L.s(18)), child: child),
        ),
      );
}

/// Tinted info panel (profile completeness, privacy notice).
class LPanel extends StatelessWidget {
  const LPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding ?? EdgeInsets.all(L.s(16)),
        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(L.r(16))),
        child: child,
      );
}

class LProgressBar extends StatelessWidget {
  const LProgressBar({super.key, required this.value, this.track});

  /// 0.0–1.0
  final double value;
  final Color? track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 8,
          color: track ?? LColors.soft,
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(color: LColors.primary, borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
      );
}

InputDecoration lInputDecoration({String? hint, Widget? prefix, String? counter}) {
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(L.r(12)),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: ts(15, color: LColors.muted),
    prefixIcon: prefix,
    counterText: counter,
    isDense: true,
    filled: true,
    fillColor: LColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    enabledBorder: border(LColors.line),
    focusedBorder: border(LColors.primary, 2),
    errorBorder: border(LColors.danger),
    focusedErrorBorder: border(LColors.danger, 2),
  );
}

/// Label above a form field.
class LField extends StatelessWidget {
  const LField({super.key, required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: ts(14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          child,
        ],
      );
}

/// Back button, title and optional subtitle for pushed screens.
class LHeader extends StatelessWidget {
  const LHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.border = true,
    this.maxWidth = LBreak.reading,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget? bottom;
  final bool border;

  /// Match the width of the content below, so the title lines up with it.
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Gutter(
        maxWidth: maxWidth,
        builder: (context, side) => Container(
          padding: EdgeInsets.fromLTRB(side, 10, side, 14),
          decoration: BoxDecoration(
            border: border ? Border(bottom: BorderSide(color: LColors.soft)) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  LIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: ts(19, weight: FontWeight.w700, height: 1.25),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: ts(14, color: LColors.text2, height: 1.35),
                          ),
                      ],
                    ),
                  ),
                  for (final a in actions) ...[const SizedBox(width: 8), a],
                ],
              ),
              if (bottom != null) ...[const SizedBox(height: 12), bottom!],
            ],
          ),
        ),
      );
}

/// Sticky footer with a top border (form buttons, detail actions).
class LFooter extends StatelessWidget {
  const LFooter({super.key, required this.children, this.maxWidth = LBreak.reading});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Gutter(
        maxWidth: maxWidth,
        builder: (context, side) => Container(
          padding: EdgeInsets.fromLTRB(side, 12, side, 16),
          decoration: BoxDecoration(
            color: LColors.bg,
            border: Border(top: BorderSide(color: LColors.soft)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: children,
            ),
          ),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.primaryAction = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool primaryAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(color: LColors.soft, shape: BoxShape.circle),
                  child: Icon(icon, size: 40, color: LColors.primary),
                ),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: ts(19, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: ts(15, color: LColors.text2, height: 1.5),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 240,
                    child: LButton(
                      label: actionLabel!,
                      onPressed: onAction,
                      height: 46,
                      radius: 12,
                      fontSize: 14,
                      kind: primaryAction ? LButtonKind.primary : LButtonKind.secondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

/// Bottom sheet with a grab handle and rounded top.
Future<T?> showLSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LColors.bg,
      barrierColor: const Color(0x8010161D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(L.r(26)))),
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: LColors.line, borderRadius: BorderRadius.circular(3)),
            ),
            Flexible(child: builder(ctx)),
          ],
        ),
      ),
    );

/// The dark toast with a check icon.
void showToast(BuildContext context, String message, {IconData icon = Icons.check_circle_rounded}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger != null) showToastOn(messenger, message, icon: icon);
}

/// [showToast] for callers without a [BuildContext] (the app root's failure notices).
void showToastOn(ScaffoldMessengerState messenger, String message, {IconData icon = Icons.check_circle_rounded}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1900),
        content: Row(
          children: [
            Icon(icon, size: 20, color: LColors.soft),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: ts(14, weight: FontWeight.w500, color: LColors.bg))),
          ],
        ),
      ),
    );
}
