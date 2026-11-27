/// The customizable look of the app: everything on the Customize panel.
///
/// To change what every student sees by default, open the panel, pick a look, tap
/// "Copy settings", and paste the values into [Appearance.new]'s defaults below.
/// To add a colour theme, add one entry to [AccentPreset]. To add a font, add one
/// entry to [AppFont].
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A colour theme: the main colour, its hover shade, and the pale tint used for highlights.
enum AccentPreset {
  navy('Classic navy', 0xFF233447, 0xFF2F4660, 0xFFE0EEFC, 0xFFA9CBF2),
  ocean('Ocean', 0xFF0B5C75, 0xFF0F7391, 0xFFDDF2F8, 0xFF8FD3E8),
  forest('Forest', 0xFF1E5B3F, 0xFF277350, 0xFFE0F2E8, 0xFF9AD9B8),
  plum('Plum', 0xFF5B2A6E, 0xFF733689, 0xFFF2E6F7, 0xFFD6AEE5),
  clay('Terracotta', 0xFF8A3B22, 0xFFA84A2D, 0xFFFBEAE3, 0xFFF0B49F);

  const AccentPreset(this.label, this.primary, this.hover, this.tint, this.onDark);

  final String label;
  final int primary;
  final int hover;
  final int tint;

  /// The main colour in dark mode (light enough to read on a dark background).
  final int onDark;
}

/// Fonts from Google Fonts.
enum AppFont {
  figtree('Figtree', 'Figtree'),
  inter('Inter', 'Inter'),
  hyperlegible('Easy reading', 'Atkinson Hyperlegible'),
  nunito('Rounded', 'Nunito');

  const AppFont(this.label, this.family);

  final String label;
  final String family;
}

enum TextSize {
  small('Small', 0.92),
  normal('Default', 1.0),
  large('Large', 1.12),
  extraLarge('Extra large', 1.25);

  const TextSize(this.label, this.scale);

  final String label;
  final double scale;
}

/// How much breathing room sits between things.
enum Spacing {
  compact('Compact', 0.75),
  comfortable('Comfortable', 1.0),
  roomy('Roomy', 1.3);

  const Spacing(this.label, this.scale);

  final String label;
  final double scale;
}

enum Corners {
  square('Square', 0.3),
  soft('Soft', 1.0),
  round('Round', 1.5);

  const Corners(this.label, this.scale);

  final String label;
  final double scale;
}

/// Languages the student can pick. Add one entry per language: [translated] marks the ones
/// whose app text is ready; the others are listed but the app text stays in English for now.
enum AppLanguage {
  english('en', 'English', 'English', translated: true),
  indonesian('id', 'Bahasa Indonesia', 'Indonesian');

  const AppLanguage(this.code, this.nativeName, this.englishName, {this.translated = false});

  /// Language code for [Locale], e.g. `id`.
  final String code;

  /// The name in its own language, shown first in the list.
  final String nativeName;
  final String englishName;
  final bool translated;
}

@immutable
class Appearance {
  const Appearance({
    this.accent = AccentPreset.navy,
    this.font = AppFont.figtree,
    this.textSize = TextSize.normal,
    this.spacing = Spacing.comfortable,
    this.corners = Corners.soft,
    this.dark = false,
    this.highContrast = false,
    this.language = AppLanguage.english,
  });

  factory Appearance.fromJson(Map<String, dynamic> json) {
    const d = Appearance();
    // Unknown or missing values fall back to the default, so old saved settings never break.
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    bool flag(Object? v, bool fallback) => v is bool ? v : fallback;
    return Appearance(
      accent: pick(AccentPreset.values, json['accent'], d.accent),
      font: pick(AppFont.values, json['font'], d.font),
      textSize: pick(TextSize.values, json['textSize'], d.textSize),
      spacing: pick(Spacing.values, json['spacing'], d.spacing),
      corners: pick(Corners.values, json['corners'], d.corners),
      dark: flag(json['dark'], d.dark),
      highContrast: flag(json['highContrast'], d.highContrast),
      language: pick(AppLanguage.values, json['language'], d.language),
    );
  }

  final AccentPreset accent;
  final AppFont font;
  final TextSize textSize;
  final Spacing spacing;
  final Corners corners;
  final bool dark;
  final bool highContrast;

  /// The language chosen under Profile > Language.
  final AppLanguage language;

  Map<String, dynamic> toJson() => {
        'accent': accent.name,
        'font': font.name,
        'textSize': textSize.name,
        'spacing': spacing.name,
        'corners': corners.name,
        'dark': dark,
        'highContrast': highContrast,
        'language': language.name,
      };

  Appearance copyWith({
    AccentPreset? accent,
    AppFont? font,
    TextSize? textSize,
    Spacing? spacing,
    Corners? corners,
    bool? dark,
    bool? highContrast,
    AppLanguage? language,
  }) =>
      Appearance(
        accent: accent ?? this.accent,
        font: font ?? this.font,
        textSize: textSize ?? this.textSize,
        spacing: spacing ?? this.spacing,
        corners: corners ?? this.corners,
        dark: dark ?? this.dark,
        highContrast: highContrast ?? this.highContrast,
        language: language ?? this.language,
      );

  @override
  bool operator ==(Object other) => other is Appearance && mapEquals(other.toJson(), toJson());

  @override
  int get hashCode => Object.hashAll(toJson().values);
}

/// Holds the current [Appearance], remembers it on this device, and opens the Customize panel.
class AppearanceController extends ChangeNotifier {
  AppearanceController({Appearance initial = const Appearance(), this.persist = false}) : _value = initial;

  static const _key = 'lumina.appearance';

  /// Restores the look saved on this device. Falls back to the default if there is none.
  static Future<AppearanceController> load() async {
    var initial = const Appearance();
    try {
      final raw = await SharedPreferencesAsync().getString(_key);
      if (raw != null) initial = Appearance.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('Lumina: could not read the saved appearance: $e');
    }
    return AppearanceController(initial: initial, persist: true);
  }

  /// False in tests: nothing is read from or written to the device.
  final bool persist;

  Appearance _value;
  Appearance get value => _value;

  bool _panelOpen = false;
  bool get panelOpen => _panelOpen;

  void openPanel() => _setPanel(true);
  void closePanel() => _setPanel(false);

  void _setPanel(bool open) {
    if (_panelOpen == open) return;
    _panelOpen = open;
    notifyListeners();
  }

  void update(Appearance next) {
    if (next == _value) return;
    _value = next;
    notifyListeners();
    if (persist) _save();
  }

  /// Back to the default look. The language is a setting of its own, so it is kept.
  void reset() => update(Appearance(language: _value.language));

  Future<void> _save() async {
    try {
      await SharedPreferencesAsync().setString(_key, jsonEncode(_value.toJson()));
    } on Object catch (e) {
      debugPrint('Lumina: could not save the appearance: $e');
    }
  }
}
