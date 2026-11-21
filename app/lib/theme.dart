import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens from Lumina_Prototype.html ("Classic Professional").
abstract final class LColors {
  static const ink = Color(0xFF1F2D3D);
  static const primary = Color(0xFF233447);
  static const primaryHover = Color(0xFF2F4660);
  static const line = Color(0xFFBCCCDC);
  static const muted = Color(0xFF9AA6B2);
  static const soft = Color(0xFFD9EAFD);
  static const bg = Color(0xFFF8FAFC);
  static const text2 = Color(0xFF5C6B7A);
  static const white = Color(0xFFFFFFFF);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: LColors.primary,
      primary: LColors.primary,
      onPrimary: LColors.bg,
      surface: LColors.bg,
      onSurface: LColors.ink,
      outline: LColors.line,
    ),
    scaffoldBackgroundColor: LColors.bg,
  );
  final text = base.textTheme.apply(
    fontFamily: GoogleFonts.figtree().fontFamily,
    bodyColor: LColors.ink,
    displayColor: LColors.ink,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: LColors.line),
  );
  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: LColors.bg,
      foregroundColor: LColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: LColors.primary, width: 1.5),
      ),
      hintStyle: const TextStyle(color: LColors.muted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LColors.primary,
        foregroundColor: LColors.bg,
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: LColors.white,
        foregroundColor: LColors.ink,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: LColors.line),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: LColors.white,
      indicatorColor: LColors.soft,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    dividerColor: LColors.soft,
  );
}

/// White card with a light border, used everywhere in the prototype.
class LCard extends StatelessWidget {
  const LCard({super.key, required this.child, this.onTap, this.padding});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: LColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

/// Small rounded label ("Full", "Masters", "Not yet verified").
class LTag extends StatelessWidget {
  const LTag(this.label, {super.key, this.strong = false});
  final String label;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: strong ? LColors.primary : LColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: strong ? LColors.primary : LColors.line),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: strong ? LColors.bg : LColors.text2,
        ),
      ),
    );
  }
}

/// Toggleable pill chip.
class LChip extends StatelessWidget {
  const LChip(this.label, {super.key, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? LColors.soft : LColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? LColors.primary : LColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!,
              style: const TextStyle(fontSize: 14, color: LColors.text2, height: 1.45)),
        ],
      ],
    );
  }
}
