import 'package:google_fonts/google_fonts.dart';
import 'package:material_ui/material_ui.dart';

import 'design/appearance.dart';

/// Every colour the app draws with, worked out from the current [Appearance].
@immutable
class LPalette {
  const LPalette({
    required this.ink,
    required this.primary,
    required this.primaryHover,
    required this.line,
    required this.muted,
    required this.soft,
    required this.bg,
    required this.text2,
    required this.text3,
    required this.white,
    required this.danger,
    required this.onPhone,
    required this.cloud,
  });

  factory LPalette.of(Appearance a) {
    final accent = a.accent;
    final strong = a.highContrast;
    if (a.dark) {
      final primary = Color(accent.onDark);
      return LPalette(
        ink: const Color(0xFFF1F5F9),
        primary: primary,
        primaryHover: Color.lerp(primary, const Color(0xFFFFFFFF), 0.2)!,
        line: strong ? const Color(0xFF7C8B9D) : const Color(0xFF3A4756),
        muted: strong ? const Color(0xFFC3CDD8) : const Color(0xFF94A3B3),
        soft: Color.alphaBlend(primary.withValues(alpha: 0.18), const Color(0xFF1A2430)),
        bg: const Color(0xFF111820),
        text2: strong ? const Color(0xFFE2E8F0) : const Color(0xFFB4C0CD),
        text3: strong ? const Color(0xFFF1F5F9) : const Color(0xFFD3DCE5),
        white: const Color(0xFF1A2430),
        danger: const Color(0xFFFFB4AB),
        onPhone: LTone(
          text: const Color(0xFF9BE5BC),
          fill: const Color(0xFF16372A),
          border: Color(strong ? 0xFF9BE5BC : 0xFF2F6B4F),
        ),
        cloud: LTone(
          text: const Color(0xFFCFC4FF),
          fill: const Color(0xFF2B2752),
          border: Color(strong ? 0xFFCFC4FF : 0xFF584B9E),
        ),
      );
    }
    return LPalette(
      ink: strong ? const Color(0xFF000000) : const Color(0xFF17222E),
      primary: Color(accent.primary),
      primaryHover: Color(accent.hover),
      line: strong ? const Color(0xFF66788A) : const Color(0xFFCBD7E3),
      muted: strong ? const Color(0xFF3F4E5E) : const Color(0xFF647485),
      soft: Color(accent.tint),
      bg: const Color(0xFFF7F9FB),
      text2: strong ? const Color(0xFF1F2D3D) : const Color(0xFF475769),
      text3: strong ? const Color(0xFF0F1A26) : const Color(0xFF2B3D50),
      white: const Color(0xFFFFFFFF),
      danger: const Color(0xFFB3261E),
      onPhone: LTone(
        text: Color(strong ? 0xFF083A22 : 0xFF14613A),
        fill: const Color(0xFFE3F4EA),
        border: Color(strong ? 0xFF083A22 : 0xFFA6D8BD),
      ),
      cloud: LTone(
        text: Color(strong ? 0xFF28156B : 0xFF4B2FA6),
        fill: const Color(0xFFEFEBFC),
        border: Color(strong ? 0xFF28156B : 0xFFC5B9F0),
      ),
    );
  }

  /// Main text.
  final Color ink;

  /// Buttons, selected states, icons that matter.
  final Color primary;
  final Color primaryHover;

  /// Borders and dividers.
  final Color line;

  /// Hints and decorative icons.
  final Color muted;

  /// Highlight background (badges, panels).
  final Color soft;

  /// Page background.
  final Color bg;

  /// Secondary text.
  final Color text2;

  /// Long body text.
  final Color text3;

  /// Card surface (dark in dark mode).
  final Color white;

  /// Errors and destructive actions.
  final Color danger;

  /// "The AI ran on this phone" (green) and "the AI ran in the cloud" (violet). Both stay the
  /// same in every colour theme, so students can learn what each one means.
  final LTone onPhone;
  final LTone cloud;
}

/// The colours of one tinted label.
@immutable
class LTone {
  const LTone({required this.text, required this.fill, required this.border});

  /// Text and icon.
  final Color text;
  final Color fill;
  final Color border;
}

/// The active colours. [applyAppearance] swaps them; the app then rebuilds every widget.
abstract final class LColors {
  static LPalette _p = LPalette.of(const Appearance());

  static Color get ink => _p.ink;
  static Color get primary => _p.primary;
  static Color get primaryHover => _p.primaryHover;
  static Color get line => _p.line;
  static Color get muted => _p.muted;
  static Color get soft => _p.soft;
  static Color get bg => _p.bg;
  static Color get text2 => _p.text2;
  static Color get text3 => _p.text3;
  static Color get white => _p.white;
  static Color get danger => _p.danger;
  static LTone get onPhone => _p.onPhone;
  static LTone get cloud => _p.cloud;
}

/// The active corner rounding and spacing.
abstract final class L {
  static double _radius = 1;
  static double _space = 1;

  /// A corner radius, scaled by the "Corners" setting.
  static double r(double base) => base * _radius;

  /// A gap or padding, scaled by the "Spacing" setting.
  static double s(double base) => base * _space;
}

/// Makes [a] the active look. Call before building widgets that read [LColors] or [L].
void applyAppearance(Appearance a) {
  LColors._p = LPalette.of(a);
  L._radius = a.corners.scale;
  L._space = a.spacing.scale;
}

/// Shorthand for inline text styles. Font family comes from the theme.
TextStyle ts(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color? color,
  double? height,
  double? spacing,
  TextDecoration? decoration,
}) =>
    TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color ?? LColors.ink,
      height: height,
      letterSpacing: spacing,
      decoration: decoration,
      decorationColor: color ?? LColors.ink,
    );

/// [googleFonts] is off in widget tests, which have no network to fetch fonts.
ThemeData buildLuminaTheme({Appearance appearance = const Appearance(), bool googleFonts = true}) {
  final brightness = appearance.dark ? Brightness.dark : Brightness.light;
  final scheme = ColorScheme.fromSeed(
    seedColor: Color(appearance.accent.primary),
    brightness: brightness,
    primary: LColors.primary,
    onPrimary: LColors.bg,
    surface: LColors.bg,
    onSurface: LColors.ink,
    outline: LColors.line,
    error: LColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LColors.bg,
    splashFactory: InkRipple.splashFactory,
    // Pushed screens fade and slide the same way everywhere; Android also previews
    // the previous screen during its back gesture.
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: platform == TargetPlatform.android
              ? const PredictiveBackPageTransitionsBuilder()
              : const FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
  final text = base.textTheme.apply(bodyColor: LColors.ink, displayColor: LColors.ink);
  return base.copyWith(
    textTheme: googleFonts ? GoogleFonts.getTextTheme(appearance.font.family, text) : text,
    textSelectionTheme: TextSelectionThemeData(cursorColor: LColors.primary),
    dividerColor: LColors.soft,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: LColors.ink,
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(L.r(14))),
      elevation: 6,
    ),
  );
}
