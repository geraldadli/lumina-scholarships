import '../models/scholarship.dart';
import '../models/user_profile.dart';
import '../util/format.dart';

enum SortBy { deadline, match }

/// Browse search + filter sheet state. Filtering is client-side: Firestore allows only one
/// `array-contains` per query and the catalog is small (contract section 1).
class BrowseFilters {
  String query = '';
  final levels = <String>{};

  /// `full` | `partial` | `any`
  final funding = <String>{};
  final countries = <String>{};
  final fields = <String>{};
  bool eligibleOnly = true;
  bool meetsGpa = false;
  bool showClosed = false;
  bool verifiedOnly = false;
  SortBy sort = SortBy.deadline;

  void reset() {
    query = '';
    levels.clear();
    funding.clear();
    countries.clear();
    fields.clear();
    eligibleOnly = true;
    meetsGpa = false;
    showClosed = false;
    verifiedOnly = false;
    sort = SortBy.deadline;
  }

  /// "Clear all": removes every chip and the search text, keeps the toggles off.
  void clearAll() {
    reset();
    eligibleOnly = false;
  }

  /// Chips shown under the search bar, each removable.
  List<({String label, void Function() remove})> get active => [
        for (final v in levels.toList()) (label: levelLabel(v), remove: () => levels.remove(v)),
        for (final v in funding.toList()) (label: fundingLabel(v), remove: () => funding.remove(v)),
        for (final v in countries.toList()) (label: countryName(v), remove: () => countries.remove(v)),
        for (final v in fields.toList()) (label: v, remove: () => fields.remove(v)),
      ];

  List<Scholarship> apply(
    List<Scholarship> all, {
    required UserProfile? profile,
    required DateTime now,
    required double Function(Scholarship) matchScore,
  }) {
    final q = query.trim().toLowerCase();
    final citizenship = normCountry(profile?.citizenship);
    final gpa = profile?.gpa;
    final out = all.where((s) {
      if (!showClosed && s.isClosedAt(now)) return false;
      if (q.isNotEmpty) {
        final hay = [s.title, s.provider, ...s.hostCountries, ...s.hostCountries.map(countryName), s.description ?? ''].join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (levels.isNotEmpty && !s.educationLevels.any(levels.contains)) return false;
      if (funding.isNotEmpty && !funding.contains('any') && !funding.contains(s.fundingType)) return false;
      if (countries.isNotEmpty && !s.hostCountries.any((c) => c == 'GLOBAL' || countries.contains(c))) return false;
      // `[]` = fields not announced yet: keep it visible (contract).
      if (fields.isNotEmpty && !s.allFields && s.fieldsOfStudy.isNotEmpty) {
        final offered = s.fieldsOfStudy.map((f) => f.toLowerCase());
        final wanted = fields.map((f) => f.toLowerCase());
        if (!offered.any((o) => wanted.any((w) => o.contains(w) || w.contains(o)))) return false;
      }
      if (eligibleOnly && citizenship != null && s.eligibleCitizenships.isNotEmpty) {
        if (!s.eligibleCitizenships.any((c) => c == 'GLOBAL' || c == citizenship)) return false;
      }
      if (meetsGpa && gpa != null && s.minGpa != null && gpa < s.minGpa!) return false;
      if (verifiedOnly && !s.verified) return false;
      return true;
    }).toList();
    out.sort((a, b) {
      if (sort == SortBy.match) return matchScore(b).compareTo(matchScore(a));
      // Deadline: open ones first by soonest deadline, closed ones last.
      final ac = a.isClosedAt(now), bc = b.isClosedAt(now);
      if (ac != bc) return ac ? 1 : -1;
      return (a.deadline ?? DateTime(9999)).compareTo(b.deadline ?? DateTime(9999));
    });
    return out;
  }
}
