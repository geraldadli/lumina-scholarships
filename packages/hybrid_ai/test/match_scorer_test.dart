import 'package:flutter_test/flutter_test.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

ScholarshipContext scholarship({
  List<String> citizenships = const ['ID'],
  List<String> levels = const ['masters', 'phd'],
  List<String> hosts = const ['JP'],
  List<String> fields = const ['ALL'],
  double? minGpa = 3.2,
  String status = 'active',
}) =>
    ScholarshipContext(
      id: 'mext-scholarship-2027',
      title: 'MEXT',
      provider: 'Government of Japan',
      fundingType: 'full',
      educationLevels: levels,
      eligibleCitizenships: citizenships,
      hostCountries: hosts,
      fieldsOfStudy: fields,
      minGpa: minGpa,
      status: status,
      requirements: [],
      benefits: [],
      sourceUrl: 'https://example.org',
    );

StudentContext student({
  String? citizenship = 'ID',
  String? level = 'masters',
  double? gpa = 3.6,
  List<String> fields = const ['Computer Science'],
  List<String> targets = const ['JP'],
}) =>
    StudentContext(
      citizenship: citizenship,
      educationLevel: level,
      gpa: gpa,
      fieldsOfStudy: fields,
      targetCountries: targets,
      skills: [],
    );

void main() {
  const scorer = MatchScorer();

  CriterionResult resultOf(MatchResult r, MatchCriterion c) => r.reasons.firstWhere((x) => x.criterion == c).result;

  test('profil yang memenuhi semua kriteria mendapat skor 1.0', () {
    final r = scorer.score(student(), scholarship());
    expect(r.score, 1.0);
    expect(r.eligible, isTrue);
    expect(r.meetsThreshold(0.65), isTrue);
  });

  test('kewarganegaraan tidak diizinkan → tidak eligible, skor dibatasi', () {
    final r = scorer.score(student(citizenship: 'MY'), scholarship());
    expect(r.eligible, isFalse);
    expect(r.score, lessThanOrEqualTo(MatchScorer.ineligibleCap));
    expect(r.meetsThreshold(0.3), isFalse);
  });

  test('GLOBAL menerima semua kewarganegaraan', () {
    final r = scorer.score(student(citizenship: 'MY'), scholarship(citizenships: ['GLOBAL']));
    expect(resultOf(r, MatchCriterion.citizenship), CriterionResult.met);
  });

  test('IPK di bawah minimum → tidak eligible', () {
    final r = scorer.score(student(gpa: 3.0), scholarship(minGpa: 3.2));
    expect(r.eligible, isFalse);
    expect(resultOf(r, MatchCriterion.gpa), CriterionResult.notMet);
  });

  test('tidak ada IPK minimum → kriteria IPK terpenuhi walau IPK kosong', () {
    final r = scorer.score(student(gpa: null), scholarship(minGpa: null));
    expect(resultOf(r, MatchCriterion.gpa), CriterionResult.met);
  });

  test('jenjang tidak dibuka → tidak eligible', () {
    final r = scorer.score(student(level: 'undergraduate'), scholarship(levels: ['masters']));
    expect(r.eligible, isFalse);
  });

  test('fieldsOfStudy kosong = belum diumumkan → unknown, bukan gagal', () {
    final r = scorer.score(student(), scholarship(fields: []));
    expect(resultOf(r, MatchCriterion.fieldOfStudy), CriterionResult.unknown);
    expect(r.eligible, isTrue);
    // 1.0 - setengah bobot bidang studi (0.15 / 2) = 0.925, dibulatkan 2 desimal.
    expect(r.score, closeTo(0.925, 0.006));
  });

  test('bidang studi dicocokkan tanpa memperhatikan huruf besar/kecil', () {
    final r = scorer.score(student(fields: ['computer science']), scholarship(fields: ['Engineering', 'Computer Science']));
    expect(resultOf(r, MatchCriterion.fieldOfStudy), CriterionResult.met);
  });

  test('kode UK dari data lama dianggap GB', () {
    final r = scorer.score(student(targets: ['GB']), scholarship(hosts: ['UK']));
    expect(resultOf(r, MatchCriterion.hostCountry), CriterionResult.met);
  });

  test('negara tujuan berbeda hanya mengurangi skor, tidak membuat tidak eligible', () {
    final r = scorer.score(student(targets: ['DE']), scholarship());
    expect(r.eligible, isTrue);
    expect(r.score, 0.9);
  });

  test('beasiswa closed → tidak eligible', () {
    final r = scorer.score(student(), scholarship(status: 'closed'));
    expect(r.eligible, isFalse);
    expect(resultOf(r, MatchCriterion.status), CriterionResult.notMet);
  });

  test('profil kosong → semua unknown, skor 0.5, tetap eligible', () {
    final r = scorer.score(
      StudentContext(targetCountries: [], fieldsOfStudy: [], skills: []),
      scholarship(fields: ['Engineering']),
    );
    expect(r.score, 0.5);
    expect(r.eligible, isTrue);
    expect(r.meetsThreshold(0.65), isFalse);
  });
}
