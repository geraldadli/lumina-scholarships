import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

/// Colour tokens from the Lumina hi-fi prototype ("Classic Professional").
abstract final class LColors {
  static const ink = Color(0xFF1F2D3D);
  static const primary = Color(0xFF233447);
  static const primaryHover = Color(0xFF2F4660);
  static const line = Color(0xFFBCCCDC);
  static const muted = Color(0xFF9AA6B2);
  static const soft = Color(0xFFD9EAFD);
  static const bg = Color(0xFFF8FAFC);
  static const text2 = Color(0xFF5C6B7A);
  static const text3 = Color(0xFF33465A);
  static const white = Color(0xFFFFFFFF);
}

/// Shorthand for the prototype's inline text styles. Font family comes from the theme (Figtree).
TextStyle ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = LColors.ink,
  double? height,
  double? spacing,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
      decoration: decoration,
      decorationColor: color,
    );

/// [googleFonts] is off in widget tests, which have no network to fetch Figtree.
ThemeData buildLuminaTheme({bool googleFonts = true}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: LColors.primary,
    primary: LColors.primary,
    onPrimary: LColors.bg,
    surface: LColors.bg,
    onSurface: LColors.ink,
    outline: LColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LColors.bg,
    splashFactory: InkRipple.splashFactory,
  );
  final text = base.textTheme.apply(bodyColor: LColors.ink, displayColor: LColors.ink);
  return base.copyWith(
    textTheme: googleFonts ? GoogleFonts.figtreeTextTheme(text) : text,
    textSelectionTheme: const TextSelectionThemeData(cursorColor: LColors.primary),
    dividerColor: LColors.soft,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LColors.ink,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 6,
    ),
  );
}
