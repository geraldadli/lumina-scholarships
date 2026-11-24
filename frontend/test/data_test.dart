import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/data/demo_backend.dart';
import 'package:lumina/data/firebase_backend.dart';
import 'package:lumina/models/user_profile.dart';
import 'package:lumina/util/format.dart';

import 'fakes.dart';

void main() {
  group('research JSON → Scholarship (demo mode, mirrors the importer)', () {
    final catalog = loadCatalog();

    test('loads every record, sorted by deadline', () {
      expect(catalog, hasLength(10));
      final deadlines = catalog.map((s) => s.deadline!).toList();
      expect(deadlines, orderedEquals([...deadlines]..sort()));
    });

    test('YYYY-MM-DD deadline is 23:59:59 WIB and round-trips to the same date', () {
      final s = catalog.firstWhere((s) => s.id == 'lpdp-australia-awards-2027');
      expect(s.deadline, DateTime.utc(2026, 5, 4, 16, 59, 59));
      expect(s.toContext().deadline, '2026-05-04');
      expect(formatDate(s.deadline!), '4 May 2026');
    });

    test('ISO deadline with a time zone is kept as an instant', () {
      final s = catalog.firstWhere((s) => s.id == 'chevening-indonesia-2027');
      expect(s.deadline, DateTime.utc(2026, 10, 6, 11));
      final f = catalog.firstWhere((s) => s.id == 'fulbright-masters-indonesia-2027');
      expect(f.deadline, DateTime.utc(2027, 2, 15, 16, 59));
      expect(formatDate(f.deadline!), '15 Feb 2027');
    });

    test('requirements get stable ids; fields not announced yet', () {
      final s = catalog.firstWhere((s) => s.id == 'australia-awards-2028');
      expect(s.requirements.first.id, 'minimum-gpa-masters-2-9-phd-3-0-equity-target-gr');
      expect(s.verified, isTrue);
      // Stipendium Hungaricum is the listing whose fields are not announced yet.
      final noFields = catalog.firstWhere((s) => s.id == 'stipendium-hungaricum-2026');
      expect(noFields.fieldsOfStudy, isEmpty);
      expect(noFields.fieldsLabel, 'Not announced yet');
    });

    test('pending-human-review is not verified', () {
      final s = parseResearchJson(
        '[{"id": "x-2027", "title": "X", "provider": "Y", "deadline": "2027-01-01", '
        '"verifiedBy": "pending-human-review"}]',
      ).single;
      expect(s.verified, isFalse);
    });

    test('closed / open state uses status and deadline', () {
      final open = catalog.where((s) => !s.isClosedAt(testNow)).map((s) => s.id).toSet();
      expect(open, {
        'australia-awards-2028',
        'fulbright-masters-indonesia-2027',
        'fulbright-phd-indonesia-2027',
        'si-global-professionals-2027',
      });
    });
  });

  group('Firestore document parsing', () {
    test('tolerates missing optional fields and legacy UK', () {
      final s = scholarshipFromFirestore('x-2027', {
        'title': 'X',
        'provider': 'Y',
        'hostCountries': ['UK'],
        'requirements': [
          {'id': 'cv', 'label': 'CV'},
        ],
        'verificationStatus': 'verified',
        'sourceUrl': 'https://example.org',
      });
      expect(s.hostCountries, ['GB']);
      expect(s.requirements.single.id, 'cv');
      expect(s.verified, isTrue);
      expect(s.status, 'active');
      expect(s.deadline, isNull);
    });
  });

  group('UserProfile', () {
    test('reads the contract fields and feeds StudentContext', () {
      final p = UserProfile.fromMap({
        'displayName': 'Kevin Sukias',
        'educationLevel': 'masters',
        'citizenship': 'id',
        'targetCountries': ['JP', 'UK'],
        'gpa': 3.4,
        'languageScores': {'ielts': 6.5, 'jlpt': 'N3'},
        'privacy': {'cloudAiAllowed': true},
        'onboardingCompleted': true,
      });
      expect(p.firstName, 'Kevin');
      expect(p.initials, 'KS');
      expect(p.cloudAiAllowed, isTrue);
      final ctx = p.toStudentContext();
      expect(ctx.citizenship, 'ID');
      expect(ctx.targetCountries, ['JP', 'GB']);
      expect(ctx.languageSummary, 'IELTS 6.5; JLPT N3');
    });

    test('completeness counts the six profile checks', () {
      expect(const UserProfile().completeness, 0);
      expect(const UserProfile(displayName: 'A', citizenship: 'ID', gpa: 3).completeness, closeTo(0.5, 1e-9));
    });
  });
}
