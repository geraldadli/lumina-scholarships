import 'package:hybrid_ai/hybrid_ai.dart';

import '../util/format.dart';

class Requirement {
  const Requirement({required this.id, required this.label});

  final String id;
  final String label;
}

/// `scholarships/{scholarshipId}`, see docs/firestore-contract.md section 1.
/// Parsing lives in the backends (Firestore / demo JSON) so this class stays plain Dart.
class Scholarship {
  const Scholarship({
    required this.id,
    required this.title,
    required this.provider,
    required this.fundingType,
    required this.educationLevels,
    required this.eligibleCitizenships,
    required this.hostCountries,
    required this.fieldsOfStudy,
    required this.status,
    required this.sourceUrl,
    this.description,
    this.minGpa,
    this.languageRequirement,
    this.openDate,
    this.deadline,
    this.isUrgent = false,
    this.requirements = const [],
    this.benefits = const [],
    this.notes,
    this.verified = false,
    this.lastVerifiedAt,
    this.lastChangeSummary,
    this.updatedAt,
    this.lastCheckedAt,
  });

  final String id;
  final String title;
  final String provider;
  final String? description;

  /// `full` | `partial`
  final String fundingType;

  /// `undergraduate` | `masters` | `phd`
  final List<String> educationLevels;

  /// ISO alpha-2 or `GLOBAL`
  final List<String> eligibleCitizenships;
  final List<String> hostCountries;

  /// `["ALL"]` = all fields; `[]` = not announced yet (never filter on it).
  final List<String> fieldsOfStudy;
  final double? minGpa;
  final String? languageRequirement;
  final DateTime? openDate;
  final DateTime? deadline;

  /// `active` | `closed`
  final String status;
  final bool isUrgent;
  final List<Requirement> requirements;
  final List<String> benefits;
  final String sourceUrl;
  final String? notes;
  final bool verified;
  final DateTime? lastVerifiedAt;
  final String? lastChangeSummary;
  final DateTime? updatedAt;
  final DateTime? lastCheckedAt;

  /// The backend closes scholarships on a schedule; also treat a passed deadline as closed
  /// so the app never shows "-2 days".
  bool isClosedAt(DateTime now) => status == 'closed' || (deadline != null && deadline!.isBefore(now));

  bool isUpcomingAt(DateTime now) => !isClosedAt(now) && openDate != null && openDate!.isAfter(now);

  int? daysLeftAt(DateTime now) {
    if (deadline == null) return null;
    // Seconds, not whole hours: with 30 minutes left it is still "1 day", not "0 days".
    return (deadline!.difference(now).inSeconds / Duration.secondsPerDay).ceil();
  }

  /// Backend sets `isUrgent` at 14 days or less; recompute too in case the flag is stale.
  bool isUrgentAt(DateTime now) {
    if (isClosedAt(now)) return false;
    final d = daysLeftAt(now);
    return isUrgent || (d != null && d <= 14);
  }

  bool get allFields => fieldsOfStudy.any((f) => f.trim().toUpperCase() == 'ALL');

  String get fieldsLabel {
    if (allFields) return 'All fields of study';
    if (fieldsOfStudy.isEmpty) return 'Not announced yet';
    return fieldsOfStudy.join(', ');
  }

  String get levelsLabel => educationLevels.map(levelLabel).join(', ');

  String get hostLabel => hostCountries.isEmpty ? '–' : hostCountries.map(countryName).join(', ');

  /// The grounding data handed to the hybrid_ai plugin.
  ScholarshipContext toContext() => ScholarshipContext(
        id: id,
        title: title,
        provider: provider,
        description: description,
        fundingType: fundingType,
        educationLevels: educationLevels,
        eligibleCitizenships: eligibleCitizenships,
        hostCountries: hostCountries,
        fieldsOfStudy: fieldsOfStudy,
        minGpa: minGpa,
        languageRequirement: languageRequirement,
        openDate: openDate == null ? null : isoDate(openDate!),
        deadline: deadline == null ? null : isoDate(deadline!),
        status: status,
        requirements: [for (final r in requirements) RequirementItem(id: r.id, label: r.label)],
        benefits: benefits,
        sourceUrl: sourceUrl,
        notes: notes,
      );
}
