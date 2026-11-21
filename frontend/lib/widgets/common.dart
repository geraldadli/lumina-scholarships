import 'package:material_ui/material_ui.dart';

import '../theme.dart';

enum LButtonKind { primary, secondary, soft, ghost }

/// The prototype's buttons: dark primary, white outlined secondary, soft-blue, and text-only.
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
          borderRadius: BorderRadius.circular(radius),
          side: border == null ? BorderSide.none : BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          hoverColor: kind == LButtonKind.primary ? LColors.primaryHover : LColors.soft,
          child: SizedBox(
            height: height,
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
                  if (icon != null) ...[Icon(icon, size: 20, color: fg), const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: ts(fontSize, weight: FontWeight.w600, color: fg),
                    ),
                  ),
                  if (trailingIcon != null) ...[const SizedBox(width: 4), Icon(trailingIcon, size: 18, color: fg)],
                ],
              ],
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
    this.size = 40,
    this.iconSize = 22,
    this.color = LColors.ink,
    this.background = LColors.white,
    this.tooltip,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;
  final String? tooltip;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    Widget button = Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(size * 0.3),
        side: const BorderSide(color: LColors.line),
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
              Icon(icon, size: iconSize, color: color),
              if (badge)
                Positioned(
                  top: size * 0.22,
                  right: size * 0.24,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: LColors.primary, shape: BoxShape.circle),
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

/// Selectable pill chip used in filters and study goals.
class LChip extends StatelessWidget {
  const LChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? LColors.soft : LColors.white,
        shape: StadiumBorder(side: BorderSide(color: selected ? LColors.primary : LColors.line)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: ts(14, weight: selected ? FontWeight.w600 : FontWeight.w500),
            ),
          ),
        ),
      );
}

/// Small rectangular tag (Full, Masters, Japan, Urgent, Closed).
class LTag extends StatelessWidget {
  const LTag(this.label, {super.key, this.strong = false, this.icon});

  final String label;
  final bool strong;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: strong ? LColors.primary : LColors.bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: strong ? LColors.primary : LColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: LColors.text2), const SizedBox(width: 3)],
            Text(label, style: ts(12, weight: FontWeight.w600, color: strong ? LColors.bg : LColors.text2)),
          ],
        ),
      );
}

/// Soft-blue badge ("Match 82%", "Cloud AI", "Ready").
class LBadge extends StatelessWidget {
  const LBadge(this.label, {super.key, this.icon, this.size = 12});

  final String label;
  final IconData? icon;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: LColors.primary), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: ts(size, weight: FontWeight.w700, color: LColors.primary),
              ),
            ),
          ],
        ),
      );
}

/// The prototype's 46x28 toggle.
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
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 46,
            height: 28,
            decoration: BoxDecoration(
              color: value ? LColors.primary : LColors.line,
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.all(3),
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: LColors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Color(0x401F2D3D), blurRadius: 3, offset: Offset(0, 1))],
                ),
              ),
            ),
          ),
        ),
      );
}

/// White bordered card with 16px radius.
class LCard extends StatelessWidget {
  const LCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => Material(
        color: color ?? LColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: LColors.bg,
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Soft-blue info panel (profile completeness, privacy notice).
class LPanel extends StatelessWidget {
  const LPanel({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: LColors.soft, borderRadius: BorderRadius.circular(16)),
        child: child,
      );
}

class LProgressBar extends StatelessWidget {
  const LProgressBar({super.key, required this.value, this.track = LColors.soft});

  /// 0.0–1.0
  final double value;
  final Color track;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Container(
          height: 6,
          color: track,
          alignment: Alignment.centerLeft,
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 300),
            widthFactor: value.clamp(0.0, 1.0),
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(color: LColors.primary, borderRadius: BorderRadius.circular(3)),
            ),
          ),
        ),
      );
}

InputDecoration lInputDecoration({String? hint, Widget? prefix, String? counter}) => InputDecoration(
      hintText: hint,
      hintStyle: ts(15, color: LColors.muted),
      prefixIcon: prefix,
      counterText: counter,
      isDense: true,
      filled: true,
      fillColor: LColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.5),
      ),
    );

/// Label above a field, as in the onboarding form.
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

/// Back button + title row used by pushed screens.
class LHeader extends StatelessWidget {
  const LHeader({super.key, required this.title, this.actions = const [], this.bottom, this.border = true});

  final String title;
  final List<Widget> actions;
  final Widget? bottom;
  final bool border;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        decoration: BoxDecoration(
          border: border ? const Border(bottom: BorderSide(color: LColors.soft)) : null,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ts(17, weight: FontWeight.w700, height: 1.2),
                  ),
                ),
                for (final a in actions) ...[const SizedBox(width: 8), a],
              ],
            ),
            if (bottom != null) ...[const SizedBox(height: 10), bottom!],
          ],
        ),
      );
}

/// Sticky footer with a top border (detail actions, form CTA).
class LFooter extends StatelessWidget {
  const LFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: const BoxDecoration(
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 56),
        child: Column(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(color: LColors.soft, shape: BoxShape.circle),
              child: Icon(icon, size: 44, color: LColors.primary),
            ),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: ts(18, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: ts(14, color: LColors.text2, height: 1.45),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: 220,
                child: LButton(
                  label: actionLabel!,
                  onPressed: onAction,
                  height: 44,
                  radius: 12,
                  fontSize: 14,
                  kind: primaryAction ? LButtonKind.primary : LButtonKind.secondary,
                ),
              ),
            ],
          ],
        ),
      );
}

/// Bottom sheet grab handle + rounded top, matching the prototype's sheets.
Future<T?> showLSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LColors.bg,
      barrierColor: const Color(0x6B1F2D3D),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
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

/// The prototype's dark toast with a check icon.
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
