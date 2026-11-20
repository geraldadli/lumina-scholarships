import 'hybrid_ai.g.dart';

/// The criteria scored by [MatchScorer].
enum MatchCriterion { citizenship, educationLevel, gpa, fieldOfStudy, hostCountry, status }

/// The result for a single criterion.
enum CriterionResult {
  /// Met.
  met,

  /// Not met.
  notMet,

  /// Profile / scholarship data is incomplete, so it cannot be judged yet.
  unknown,
}

class MatchReason {
  const MatchReason(this.criterion, this.result, this.message);

  final MatchCriterion criterion;
  final CriterionResult result;

  /// A short explanation (English) to show in the UI.
  final String message;
}

class MatchResult {
  const MatchResult({required this.score, required this.eligible, required this.reasons});

  /// 0.0–1.0. Compare with Remote Config `min_match_score_threshold` (see [AiStatus.minMatchScore]).
  final double score;

  /// `false` when a mandatory requirement is clearly not met (citizenship, education level, GPA, closed status).
  final bool eligible;
  final List<MatchReason> reasons;

  bool meetsThreshold(double threshold) => eligible && score >= threshold;
}

/// Rule-based student ↔ scholarship match score: fast, consistent, works offline,
/// and explainable. The AI is used to EXPLAIN this result, not to replace it.
///
/// Weights: citizenship 0.30, education level 0.25, GPA 0.20, field of study 0.15, host country 0.10.
/// A criterion that cannot be judged yet gets half its weight.
class MatchScorer {
  const MatchScorer();

  static const _weights = <MatchCriterion, double>{
    MatchCriterion.citizenship: 0.30,
    MatchCriterion.educationLevel: 0.25,
    MatchCriterion.gpa: 0.20,
    MatchCriterion.fieldOfStudy: 0.15,
    MatchCriterion.hostCountry: 0.10,
  };

  /// Maximum score when a mandatory requirement is not met (below the default threshold of 0.65).
  static const ineligibleCap = 0.4;

  static const _hard = {
    MatchCriterion.citizenship,
    MatchCriterion.educationLevel,
    MatchCriterion.gpa,
    MatchCriterion.status,
  };

  MatchResult score(StudentContext student, ScholarshipContext scholarship) {
    final reasons = <MatchReason>[
      _citizenship(student, scholarship),
      _educationLevel(student, scholarship),
      _gpa(student, scholarship),
      _fieldOfStudy(student, scholarship),
      _hostCountry(student, scholarship),
      if (scholarship.status.toLowerCase() == 'closed')
        const MatchReason(MatchCriterion.status, CriterionResult.notMet, 'Applications are closed.'),
    ];

    var total = 0.0;
    for (final r in reasons) {
      final w = _weights[r.criterion] ?? 0;
      total += switch (r.result) {
        CriterionResult.met => w,
        CriterionResult.unknown => w / 2,
        CriterionResult.notMet => 0,
      };
    }
    final eligible = !reasons.any((r) => _hard.contains(r.criterion) && r.result == CriterionResult.notMet);
    if (!eligible && total > ineligibleCap) total = ineligibleCap;
    return MatchResult(score: double.parse(total.toStringAsFixed(2)), eligible: eligible, reasons: reasons);
  }

  MatchReason _citizenship(StudentContext st, ScholarshipContext s) {
    final c = _country(st.citizenship);
    if (c == null) {
      return const MatchReason(MatchCriterion.citizenship, CriterionResult.unknown, 'Citizenship is not filled in on your profile.');
    }
    final allowed = s.eligibleCitizenships.map(_country).whereType<String>().toSet();
    if (allowed.isEmpty) {
      return const MatchReason(MatchCriterion.citizenship, CriterionResult.unknown, 'Citizenship requirements are not available yet.');
    }
    return allowed.contains('GLOBAL') || allowed.contains(c)
        ? const MatchReason(MatchCriterion.citizenship, CriterionResult.met, 'Your citizenship meets the requirement.')
        : const MatchReason(MatchCriterion.citizenship, CriterionResult.notMet, 'Your citizenship is not among the eligible ones.');
  }

  MatchReason _educationLevel(StudentContext st, ScholarshipContext s) {
    final level = st.educationLevel?.trim().toLowerCase();
    if (level == null || level.isEmpty) {
      return const MatchReason(MatchCriterion.educationLevel, CriterionResult.unknown, 'Target education level is not filled in on your profile.');
    }
    final levels = s.educationLevels.map((e) => e.trim().toLowerCase()).toSet();
    if (levels.isEmpty) {
      return const MatchReason(MatchCriterion.educationLevel, CriterionResult.unknown, 'Education levels for this scholarship are not available yet.');
    }
    return levels.contains(level)
        ? const MatchReason(MatchCriterion.educationLevel, CriterionResult.met, 'Education level matches.')
        : const MatchReason(MatchCriterion.educationLevel, CriterionResult.notMet, 'This scholarship does not cover the education level you are aiming for.');
  }

  MatchReason _gpa(StudentContext st, ScholarshipContext s) {
    final min = s.minGpa;
    if (min == null || min <= 0) {
      return const MatchReason(MatchCriterion.gpa, CriterionResult.met, 'No minimum GPA requirement.');
    }
    final gpa = st.gpa;
    if (gpa == null) return const MatchReason(MatchCriterion.gpa, CriterionResult.unknown, 'GPA is not filled in on your profile.');
    return gpa >= min
        ? MatchReason(MatchCriterion.gpa, CriterionResult.met, 'Your GPA of ${_fmt(gpa)} meets the minimum of ${_fmt(min)}.')
        : MatchReason(MatchCriterion.gpa, CriterionResult.notMet, 'Your GPA of ${_fmt(gpa)} is below the minimum of ${_fmt(min)}.');
  }

  MatchReason _fieldOfStudy(StudentContext st, ScholarshipContext s) {
    final offered = s.fieldsOfStudy.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toSet();
    if (offered.contains('all')) {
      return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.met, 'Open to all fields of study.');
    }
    // `[]` in the data contract = fields not announced yet: do not treat it as a mismatch.
    if (offered.isEmpty) {
      return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.unknown, 'The provider has not announced the fields of study yet.');
    }
    final mine = st.fieldsOfStudy.map((e) => e.trim().toLowerCase()).where((e) => e.isNotEmpty).toList();
    if (mine.isEmpty) {
      return const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.unknown, 'Field of study is not filled in on your profile.');
    }
    final match = mine.any((m) => offered.any((o) => o.contains(m) || m.contains(o)));
    return match
        ? const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.met, 'Field of study matches.')
        : const MatchReason(MatchCriterion.fieldOfStudy, CriterionResult.notMet, 'Your field of study is not listed.');
  }

  MatchReason _hostCountry(StudentContext st, ScholarshipContext s) {
    final hosts = s.hostCountries.map(_country).whereType<String>().toSet();
    final targets = st.targetCountries.map(_country).whereType<String>().toSet();
    if (targets.isEmpty) {
      return const MatchReason(MatchCriterion.hostCountry, CriterionResult.unknown, 'Target countries are not filled in on your profile.');
    }
    if (hosts.isEmpty) {
      return const MatchReason(MatchCriterion.hostCountry, CriterionResult.unknown, 'The host country for this scholarship is not available yet.');
    }
    return hosts.contains('GLOBAL') || hosts.any(targets.contains)
        ? const MatchReason(MatchCriterion.hostCountry, CriterionResult.met, 'Host country matches your preferences.')
        : const MatchReason(MatchCriterion.hostCountry, CriterionResult.notMet, 'Host country differs from your preferences.');
  }

  /// Normalizes a country code: uppercase, and `UK` (old data) is treated as `GB`.
  static String? _country(String? raw) {
    final c = raw?.trim().toUpperCase();
    if (c == null || c.isEmpty) return null;
    return c == 'UK' ? 'GB' : c;
  }

  static String _fmt(double v) => v.toStringAsFixed(2);
}
