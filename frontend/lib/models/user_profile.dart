import 'package:hybrid_ai/hybrid_ai.dart';

import '../util/format.dart';

/// `users/{uid}.languageScores`: fixed keys from the contract, all optional.
class LanguageScores {
  const LanguageScores({this.ielts, this.toeflIbt, this.duolingo, this.jlpt, this.topik});

  final double? ielts;
  final double? toeflIbt;
  final double? duolingo;

  /// `N1`–`N5`
  final String? jlpt;

  /// 1–6
  final double? topik;

  bool get isEmpty => ielts == null && toeflIbt == null && duolingo == null && jlpt == null && topik == null;

  /// `IELTS 6.5; JLPT N3`, the format `StudentContext.languageSummary` expects.
  String? get summary {
    String n(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    final parts = [
      if (ielts != null) 'IELTS ${n(ielts!)}',
      if (toeflIbt != null) 'TOEFL iBT ${n(toeflIbt!)}',
      if (duolingo != null) 'Duolingo ${n(duolingo!)}',
      if (jlpt != null) 'JLPT $jlpt',
      if (topik != null) 'TOPIK ${n(topik!)}',
    ];
    return parts.isEmpty ? null : parts.join('; ');
  }

  Map<String, Object> toMap() => {
        'ielts': ?ielts,
        'toeflIbt': ?toeflIbt,
        'duolingo': ?duolingo,
        'jlpt': ?jlpt,
        'topik': ?topik,
      };

  factory LanguageScores.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const LanguageScores();
    double? d(Object? v) => v is num ? v.toDouble() : null;
    return LanguageScores(
      ielts: d(m['ielts']),
      toeflIbt: d(m['toeflIbt']),
      duolingo: d(m['duolingo']),
      jlpt: m['jlpt'] is String ? m['jlpt'] as String : null,
      topik: d(m['topik']),
    );
  }
}

/// `users/{uid}`, see docs/firestore-contract.md section 2.
class UserProfile {
  const UserProfile({
    this.displayName = '',
    this.educationLevel,
    this.currentEducationLevel,
    this.citizenship,
    this.targetCountries = const [],
    this.fieldsOfStudy = const [],
    this.gpa,
    this.languageScores = const LanguageScores(),
    this.fundingPreference,
    this.cloudAiAllowed = false,
    this.onboardingCompleted = false,
    this.cvSkills = const [],
    this.cvExperienceYears,
  });

  final String displayName;

  /// The level the student wants to study: `undergraduate` | `masters` | `phd`.
  final String? educationLevel;

  /// `high_school` | `undergraduate` | `masters` | `phd`
  final String? currentEducationLevel;

  /// ISO alpha-2
  final String? citizenship;
  final List<String> targetCountries;
  final List<String> fieldsOfStudy;
  final double? gpa;
  final LanguageScores languageScores;

  /// `full` | `partial` | `any`
  final String? fundingPreference;

  /// `privacy.cloudAiAllowed`. `false` = private mode (Gemini Nano only).
  final bool cloudAiAllowed;
  final bool onboardingCompleted;

  /// From `cvSummary` (read-only here; CV import comes in a later sprint).
  final List<String> cvSkills;
  final int? cvExperienceYears;

  String get firstName {
    final n = displayName.trim();
    return n.isEmpty ? 'there' : n.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    final s = parts.map((p) => p[0]).join().toUpperCase();
    return s.isEmpty ? '?' : (s.length > 2 ? s.substring(0, 2) : s);
  }

  /// Same six checks as the prototype's completeness bar.
  double get completeness {
    final checks = [
      displayName.trim().isNotEmpty,
      citizenship != null,
      currentEducationLevel != null || educationLevel != null,
      gpa != null,
      !languageScores.isEmpty,
      targetCountries.isNotEmpty,
    ];
    return checks.where((c) => c).length / checks.length;
  }

  StudentContext toStudentContext() => StudentContext(
        educationLevel: educationLevel,
        citizenship: normCountry(citizenship),
        targetCountries: targetCountries,
        fieldsOfStudy: fieldsOfStudy,
        gpa: gpa,
        languageSummary: languageScores.summary,
        skills: cvSkills,
        experienceYears: cvExperienceYears,
      );

  UserProfile copyWith({
    String? displayName,
    String? Function()? educationLevel,
    String? Function()? currentEducationLevel,
    String? Function()? citizenship,
    List<String>? targetCountries,
    List<String>? fieldsOfStudy,
    double? Function()? gpa,
    LanguageScores? languageScores,
    String? Function()? fundingPreference,
    bool? cloudAiAllowed,
    bool? onboardingCompleted,
  }) =>
      UserProfile(
        displayName: displayName ?? this.displayName,
        educationLevel: educationLevel != null ? educationLevel() : this.educationLevel,
        currentEducationLevel: currentEducationLevel != null ? currentEducationLevel() : this.currentEducationLevel,
        citizenship: citizenship != null ? citizenship() : this.citizenship,
        targetCountries: targetCountries ?? this.targetCountries,
        fieldsOfStudy: fieldsOfStudy ?? this.fieldsOfStudy,
        gpa: gpa != null ? gpa() : this.gpa,
        languageScores: languageScores ?? this.languageScores,
        fundingPreference: fundingPreference != null ? fundingPreference() : this.fundingPreference,
        cloudAiAllowed: cloudAiAllowed ?? this.cloudAiAllowed,
        onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
        cvSkills: cvSkills,
        cvExperienceYears: cvExperienceYears,
      );

  /// Reads the plain-JSON fields of a `users/{uid}` document (timestamps are ignored here).
  factory UserProfile.fromMap(Map<String, dynamic> m) {
    List<String> strings(Object? v) => v is List ? v.whereType<String>().toList() : const [];
    final cv = m['cvSummary'];
    final privacy = m['privacy'];
    return UserProfile(
      displayName: m['displayName'] as String? ?? '',
      educationLevel: m['educationLevel'] as String?,
      currentEducationLevel: m['currentEducationLevel'] as String?,
      citizenship: normCountry(m['citizenship'] as String?),
      targetCountries: strings(m['targetCountries']).map((c) => normCountry(c)!).toList(),
      fieldsOfStudy: strings(m['fieldsOfStudy']),
      gpa: (m['gpa'] as num?)?.toDouble(),
      languageScores: LanguageScores.fromMap((m['languageScores'] as Map?)?.cast<String, dynamic>()),
      fundingPreference: m['fundingPreference'] as String?,
      cloudAiAllowed: privacy is Map && privacy['cloudAiAllowed'] == true,
      onboardingCompleted: m['onboardingCompleted'] == true,
      cvSkills: cv is Map ? strings(cv['skills']) : const [],
      cvExperienceYears: cv is Map ? (cv['experienceYears'] as num?)?.toInt() : null,
    );
  }
}
