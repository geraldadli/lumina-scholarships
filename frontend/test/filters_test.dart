import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/state/browse_filters.dart';

import 'fakes.dart';

void main() {
  final catalog = loadCatalog();
  const student = UserProfile(citizenship: 'ID', educationLevel: 'masters', gpa: 3.2);

  List<String> run(BrowseFilters f, {UserProfile? profile = student}) =>
      f.apply(catalog, profile: profile, now: testNow, matchScore: (_) => 0).map((s) => s.id).toList();

  test('hides closed scholarships unless "Show closed" is on', () {
    final f = BrowseFilters();
    expect(run(f), hasLength(4));
    f.showClosed = true;
    expect(run(f), hasLength(12));
    // Closed ones sort last.
    expect(run(f).take(4).toSet(), run(BrowseFilters()).toSet());
  });

  test('education level filter', () {
    final f = BrowseFilters()..levels.add('phd');
    expect(run(f), isNot(contains('fulbright-masters-indonesia-2027')));
    expect(run(f), contains('fulbright-phd-indonesia-2027'));
  });

  test('fields not announced yet ([]) stay visible under a field filter', () {
    final f = BrowseFilters()
      ..showClosed = true
      ..fields.add('Medicine');
    expect(run(f), contains('australia-awards-2027'));
  });

  test('host country GLOBAL matches any country filter', () {
    final f = BrowseFilters()
      ..showClosed = true
      ..countries.add('JP');
    final ids = run(f);
    expect(ids, contains('mext-research-student-2027'));
    expect(ids, contains('lpdp-share-2026-tahap-2'));
    expect(ids, isNot(contains('chevening-indonesia-2027')));
  });

  test('search matches title, provider and country name', () {
    final f = BrowseFilters()
      ..showClosed = true
      ..query = 'sweden';
    expect(run(f), ['si-global-professionals-2027']);
  });

  test('clearAll removes chips and the eligibility toggle', () {
    final f = BrowseFilters()
      ..levels.add('phd')
      ..query = 'x';
    f.clearAll();
    expect(f.active, isEmpty);
    expect(f.query, isEmpty);
    expect(f.eligibleOnly, isFalse);
  });
}
