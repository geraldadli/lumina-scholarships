import 'package:hybrid_ai/hybrid_ai.dart';

/// Mirrors `scholarships/{id}` in docs/firestore-contract.md §1.
class Scholarship {
  const Scholarship({
    required this.id,
    required this.title,
    required this.provider,
    required this.description,
    required this.fundingType,
    required this.educationLevels,
    required this.eligibleCitizenships,
    required this.hostCountries,
    required this.fieldsOfStudy,
    required this.deadline,
    required this.status,
    required this.sourceUrl,
    this.minGpa,
    this.languageRequirement,
    this.openDate,
    this.requirements = const [],
    this.benefits = const [],
    this.notes,
    this.verificationStatus = 'pending',
    this.lastChangeSummary,
    this.updatedAt,
  });

  final String id, title, provider, description, fundingType, status, sourceUrl;
  final List<String> educationLevels, eligibleCitizenships, hostCountries, fieldsOfStudy;
  final DateTime deadline;
  final DateTime? openDate, updatedAt;
  final double? minGpa;
  final String? languageRequirement, notes, lastChangeSummary;
  final List<RequirementItem> requirements;
  final List<String> benefits;
  final String verificationStatus;

  bool get isActive => status == 'active';
  bool get isVerified => verificationStatus == 'verified';
  int get daysLeft => deadline.difference(DateTime.now()).inDays;
  bool get isUrgent => isActive && daysLeft >= 0 && daysLeft <= 14;
  bool get opensSoon => openDate != null && openDate!.isAfter(DateTime.now());
  String get hostLabel => hostCountries.map(countryName).join(', ');
  String get levelLabel => educationLevels.map(levelName).join(' / ');
  String get fundingLabel => fundingType == 'full' ? 'Full funding' : 'Partial funding';
  String get sourceHost => Uri.tryParse(sourceUrl)?.host.replaceFirst('www.', '') ?? sourceUrl;
  String get fieldsLabel => fieldsOfStudy.isEmpty
      ? 'Not announced yet'
      : fieldsOfStudy.contains('ALL')
          ? 'All fields of study'
          : fieldsOfStudy.join(', ');

  ScholarshipContext toAiContext() => ScholarshipContext(
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
        openDate: openDate?.toIso8601String(),
        deadline: deadline.toIso8601String(),
        status: status,
        requirements: requirements,
        benefits: benefits,
        sourceUrl: sourceUrl,
        notes: notes,
      );
}

/// Mirrors `users/{uid}` (§2).
class UserProfile {
  String displayName = '';
  String? citizenship = 'ID';
  String? currentEducationLevel;
  String? educationLevel;
  List<String> fieldsOfStudy = [];
  List<String> targetCountries = [];
  String fundingPreference = 'any';
  double? gpa;
  Map<String, Object> languageScores = {};
  bool cloudAiAllowed = false;
  bool onboardingCompleted = false;

  /// Share of the profile fields used for matching that are filled in.
  double get completeness {
    final filled = [
      displayName.isNotEmpty,
      citizenship != null,
      educationLevel != null,
      fieldsOfStudy.isNotEmpty,
      targetCountries.isNotEmpty,
      gpa != null,
      languageScores.isNotEmpty,
    ].where((b) => b).length;
    return filled / 7;
  }

  StudentContext toAiContext() => StudentContext(
        educationLevel: educationLevel,
        citizenship: citizenship,
        targetCountries: targetCountries,
        fieldsOfStudy: fieldsOfStudy,
        gpa: gpa,
        languageSummary: languageScores.isEmpty
            ? null
            : languageScores.entries.map((e) => '${e.key} ${e.value}').join(', '),
        skills: const [],
      );
}

/// Mirrors `users/{uid}/saved_scholarships/{id}` (§3).
class SavedScholarship {
  SavedScholarship({required this.scholarshipId, this.status = 'saved', this.lastSeenUpdatedAt});
  final String scholarshipId;
  String status; // saved | preparing | applied
  List<ChecklistEntry> checklist = [];
  String notes = '';
  DateTime? lastSeenUpdatedAt;
}

class ChecklistEntry {
  ChecklistEntry({required this.id, required this.label, this.tip, this.done = false});
  final String id, label;
  final String? tip;
  bool done;
}

const educationLevels = ['undergraduate', 'masters', 'phd'];

String levelName(String l) => switch (l) {
      'high_school' => 'High school',
      'undergraduate' => 'Undergraduate',
      'masters' => 'Masters',
      'phd' => 'PhD',
      _ => l,
    };

const countryNames = {
  'ID': 'Indonesia', 'AU': 'Australia', 'US': 'United States', 'GB': 'United Kingdom',
  'JP': 'Japan', 'KR': 'South Korea', 'DE': 'Germany', 'NL': 'Netherlands', 'SG': 'Singapore',
  'SE': 'Sweden', 'CN': 'China', 'TR': 'Türkiye', 'HU': 'Hungary', 'GLOBAL': 'Any country',
};

String countryName(String code) {
  final c = code == 'UK' ? 'GB' : code; // contract: treat legacy UK as GB
  return countryNames[c] ?? c;
}

String formatDate(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}
