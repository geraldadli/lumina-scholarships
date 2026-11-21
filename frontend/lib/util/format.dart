/// Country names, date formatting and small label helpers shared by the screens.
library;

/// ISO 3166-1 alpha-2 → display name. Covers the citizenships and host countries in the catalog.
const countryNames = <String, String>{
  'ID': 'Indonesia',
  'VN': 'Vietnam',
  'IN': 'India',
  'NG': 'Nigeria',
  'PH': 'Philippines',
  'KE': 'Kenya',
  'BR': 'Brazil',
  'MY': 'Malaysia',
  'TH': 'Thailand',
  'PK': 'Pakistan',
  'BD': 'Bangladesh',
  'GH': 'Ghana',
  'JP': 'Japan',
  'KR': 'South Korea',
  'DE': 'Germany',
  'GB': 'UK',
  'US': 'US',
  'AU': 'Australia',
  'SG': 'Singapore',
  'NL': 'Netherlands',
  'SE': 'Sweden',
  'CN': 'China',
  'TR': 'Türkiye',
  'HU': 'Hungary',
};

/// Citizenship options for onboarding (contract: ISO alpha-2, the rules require exactly 2 letters).
const citizenshipOptions = ['ID', 'VN', 'IN', 'NG', 'PH', 'KE', 'BR', 'MY', 'TH', 'PK', 'BD', 'GH'];

/// Host-country chips for study goals and filters.
const targetCountryOptions = ['JP', 'KR', 'DE', 'GB', 'AU', 'US', 'NL', 'SE', 'CN', 'TR', 'HU', 'SG'];

const fieldOptions = ['Computer Science', 'Engineering', 'Medicine', 'Business', 'Social Science'];

/// Normalises a country code: uppercase, legacy `UK` → `GB` (contract, general conventions).
String? normCountry(String? raw) {
  final c = raw?.trim().toUpperCase();
  if (c == null || c.isEmpty) return null;
  return c == 'UK' ? 'GB' : c;
}

String countryName(String code) {
  final c = normCountry(code) ?? code;
  if (c == 'GLOBAL') return 'Any country';
  return countryNames[c] ?? c;
}

const levelLabels = {'undergraduate': 'Undergraduate', 'masters': 'Masters', 'phd': 'PhD'};
const currentLevelLabels = {
  'high_school': 'High school',
  'undergraduate': "Bachelor's degree",
  'masters': "Master's degree",
  'phd': 'Doctorate',
};
const fundingLabels = {'full': 'Full', 'partial': 'Partial', 'any': 'Any'};

String levelLabel(String v) => levelLabels[v] ?? v;
String fundingLabel(String v) => fundingLabels[v] ?? v;

/// Deadlines are published in WIB (UTC+7) by the research team, so dates are shown in WIB
/// to keep "30 Apr" from turning into "29 Apr" on a phone set to another time zone.
DateTime toWib(DateTime t) => t.toUtc().add(const Duration(hours: 7));

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// `15 Feb 2027`
String formatDate(DateTime t) {
  final w = toWib(t);
  return '${w.day} ${_months[w.month - 1]} ${w.year}';
}

/// `15 Feb`
String formatShortDate(DateTime t) {
  final w = toWib(t);
  return '${w.day} ${_months[w.month - 1]}';
}

/// `YYYY-MM-DD` in WIB, the format `ScholarshipContext` expects.
String isoDate(DateTime t) {
  final w = toWib(t);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${w.year}-${two(w.month)}-${two(w.day)}';
}

/// "3 hours ago" style relative time for "last checked".
String timeAgo(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'} ago';
  if (d.inDays < 30) return '${d.inDays} day${d.inDays == 1 ? '' : 's'} ago';
  return 'on ${formatDate(t)}';
}

/// `chevening.org` from `https://www.chevening.org/scholarships/…`
String hostOf(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return url;
  return host.startsWith('www.') ? host.substring(4) : host;
}

/// Stable id for a checklist item, same idea as the backend importer (`ielts`, `motivation-letter`).
String slugify(String label) {
  final s = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return s.length > 48 ? s.substring(0, 48) : s;
}

String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';
