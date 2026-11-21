import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/saved_scholarship.dart';
import '../models/scholarship.dart';
import '../models/user_profile.dart';
import '../util/format.dart';
import 'backend.dart';

/// In-memory backend for running the app before google-services.json arrives.
///
/// The catalog is a copy of backend/data/scholarships.json (the research team's format),
/// converted the same way the backend importer does (contract section 5). Nothing is persisted.
class DemoBackend implements LuminaBackend {
  DemoBackend(List<Scholarship> catalog) : _catalog = _Live(catalog);

  static const assetPath = 'assets/demo/scholarships.json';

  static Future<DemoBackend> fromAsset() async {
    final raw = await rootBundle.loadString(assetPath);
    return DemoBackend(parseResearchJson(raw));
  }

  final _Live<List<Scholarship>> _catalog;
  final _auth = _Live<AuthUser?>(null);
  final _profile = _Live<UserProfile?>(null);
  final _saved = _Live<Map<String, SavedScholarship>>(const {});

  static const _demoUser = AuthUser(uid: 'demo-student', email: 'demo@lumina.app');

  @override
  bool get isDemo => true;

  @override
  Stream<AuthUser?> authState() => _auth.stream;

  @override
  Future<void> signInWithGoogle() async {
    _password = null;
    _auth.set(_demoUser);
  }

  /// The password used to sign in, so deleting the account can be confirmed like in Firebase.
  String? _password;

  @override
  Future<void> signInWithEmail(String email, String password) async {
    _password = password;
    _auth.set(AuthUser(
      uid: _demoUser.uid,
      email: email.trim().isEmpty ? _demoUser.email : email.trim(),
      // Welcome's one-tap demo sign-in has no password, so it has none to confirm with either.
      usesPassword: password.isNotEmpty,
    ));
  }

  @override
  Future<void> createAccountWithEmail(String email, String password) => signInWithEmail(email, password);

  /// Demo mode sends no email; it only checks the address like Firebase would.
  @override
  Future<void> sendPasswordReset(String email) async {
    if (!email.contains('@')) throw const AuthFailure('That email address is not valid.');
  }

  @override
  Future<void> signOut() async => _auth.set(null);

  @override
  Future<void> deleteAccount(String uid, {String? password}) async {
    if (_auth.value?.usesPassword ?? false) {
      if (password == null || password.isEmpty) throw const AuthFailure('Enter your password to confirm.');
      if (password != _password) throw const AuthFailure('Email or password is incorrect.');
    }
    _saved.set(const {});
    _profile.set(null);
    _auth.set(null);
  }

  @override
  Stream<UserProfile?> profile(String uid) => _profile.stream;

  @override
  Future<void> saveProfile(String uid, UserProfile profile, {required bool isNew}) async => _profile.set(profile);

  @override
  Stream<List<Scholarship>> scholarships() => _catalog.stream;

  /// Replaces the catalog, e.g. after the research file changes or a listing is withdrawn.
  void setCatalog(List<Scholarship> catalog) => _catalog.set(catalog);

  @override
  Stream<Map<String, SavedScholarship>> saved(String uid) => _saved.stream;

  @override
  Future<void> save(
    String uid,
    Scholarship s, {
    double? matchScore,
    String status = 'saved',
    List<ChecklistEntry> checklist = const [],
  }) async {
    _saved.set({
      ..._saved.value,
      s.id: SavedScholarship(
        scholarshipId: s.id,
        status: status,
        matchScore: matchScore,
        checklist: checklist,
        lastSeenUpdatedAt: s.updatedAt,
        savedAt: DateTime.now(),
      ),
    });
  }

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) async {
    final cur = _saved.value[scholarshipId];
    if (cur == null) return;
    _saved.set({
      ..._saved.value,
      scholarshipId: cur.copyWith(
        status: patch.status,
        checklist: patch.checklist,
        notes: patch.notes,
        lastSeenUpdatedAt: patch.lastSeenUpdatedAt,
      ),
    });
  }

  @override
  Future<void> unsave(String uid, String scholarshipId) async {
    _saved.set({..._saved.value}..remove(scholarshipId));
  }
}

/// A value that replays its latest state to every new listener (like a Firestore snapshot stream).
class _Live<T> {
  _Live(this.value);

  T value;
  final _changes = StreamController<T>.broadcast(sync: true);

  Stream<T> get stream => Stream<T>.multi((sink) {
        sink.add(value);
        final sub = _changes.stream.listen(sink.add);
        sink.onCancel = sub.cancel;
      });

  void set(T v) {
    value = v;
    _changes.add(v);
  }
}

/// Converts backend/data/scholarships.json into [Scholarship]s, mirroring the importer:
/// `YYYY-MM-DD` deadlines become 23:59:59 WIB, open dates 00:00 WIB, requirement strings
/// become `{id, label}`, and `verifiedBy: pending-human-review` means not verified.
List<Scholarship> parseResearchJson(String raw) {
  final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  final out = list.map(_fromResearch).toList()
    ..sort((a, b) => (a.deadline ?? DateTime(9999)).compareTo(b.deadline ?? DateTime(9999)));
  return out;
}

final _dateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

DateTime? _wibDate(Object? v, {required bool endOfDay}) {
  if (v is! String || v.isEmpty) return null;
  if (_dateOnly.hasMatch(v)) {
    final p = v.split('-').map(int.parse).toList();
    // WIB = UTC+7
    return endOfDay
        ? DateTime.utc(p[0], p[1], p[2], 23, 59, 59).subtract(const Duration(hours: 7))
        : DateTime.utc(p[0], p[1], p[2]).subtract(const Duration(hours: 7));
  }
  return DateTime.tryParse(v)?.toUtc();
}

Scholarship _fromResearch(Map<String, dynamic> d) {
  List<String> strings(Object? v) => v is List ? v.whereType<String>().toList() : const [];
  final verifiedBy = d['verifiedBy'] as String?;
  final verified = verifiedBy != null && verifiedBy.isNotEmpty && verifiedBy != 'pending-human-review';
  final lastVerified = _wibDate(d['lastVerified'], endOfDay: false);
  return Scholarship(
    id: d['id'] as String,
    title: d['title'] as String? ?? '',
    provider: d['provider'] as String? ?? '',
    description: d['description'] as String?,
    fundingType: d['fundingType'] as String? ?? 'full',
    educationLevels: strings(d['educationLevels']),
    eligibleCitizenships: strings(d['eligibleCitizenships']).map((c) => normCountry(c)!).toList(),
    hostCountries: strings(d['hostCountries']).map((c) => normCountry(c)!).toList(),
    fieldsOfStudy: strings(d['fieldsOfStudy']),
    minGpa: (d['minGpa'] as num?)?.toDouble(),
    languageRequirement: d['languageRequirement'] as String?,
    openDate: _wibDate(d['openDate'], endOfDay: false),
    deadline: _wibDate(d['deadline'], endOfDay: true),
    status: d['status'] as String? ?? 'active',
    requirements: [for (final r in strings(d['requirements'])) Requirement(id: slugify(r), label: r)],
    benefits: strings(d['benefits']),
    sourceUrl: d['sourceUrl'] as String? ?? '',
    notes: d['notes'] as String?,
    verified: verified,
    lastVerifiedAt: verified ? lastVerified : null,
    lastChangeSummary: d['changeSummary'] as String?,
    updatedAt: lastVerified,
    lastCheckedAt: lastVerified,
  );
}
