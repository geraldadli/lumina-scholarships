import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hybrid_ai/hybrid_ai.dart';

import 'data/firestore_mapping.dart';
import 'models.dart';

/// App-wide state backed by Firebase Auth + Firestore (docs/firestore-contract.md).
class AppState extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final ai = HybridAi();

  User? user;
  bool authReady = false;
  bool profileLoaded = false;

  List<Scholarship> scholarships = [];
  List<Scholarship> _bundled = [];
  bool catalogIsLive = false;
  String? catalogError;

  UserProfile profile = UserProfile();
  final Map<String, SavedScholarship> saved = {};
  double minMatchScore = 0.65; // Remote Config default (contract §6)

  StreamSubscription<User?>? _authSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _catalogSub, _savedSub;
  final Map<String, Timer> _savedDebounce = {};

  DocumentReference<Map<String, dynamic>> get _userDoc => _db.collection('users').doc(user!.uid);
  CollectionReference<Map<String, dynamic>> get _savedCol => _userDoc.collection('saved_scholarships');

  Future<void> init() async {
    _bundled = await _loadBundled();
    scholarships = _bundled;
    _authSub = _auth.authStateChanges().listen(_onAuth);
    unawaited(_loadRemoteConfig());
  }

  Future<void> _loadRemoteConfig() async {
    try {
      // The hybrid_ai plugin fetches Remote Config (with the contract's defaults).
      minMatchScore = (await ai.getStatus()).minMatchScore;
      notifyListeners();
    } catch (_) {/* keep default */}
  }

  Future<void> _onAuth(User? u) async {
    await _catalogSub?.cancel();
    await _savedSub?.cancel();
    user = u;
    authReady = true;
    profileLoaded = false;
    profile = UserProfile();
    saved.clear();
    scholarships = _bundled;
    catalogIsLive = false;
    notifyListeners();
    if (u == null) return;

    // Catalog: read = any signed-in user. Small catalog, so take all docs and filter on the client.
    _catalogSub = _db.collection('scholarships').snapshots().listen((snap) {
      catalogError = null;
      if (snap.docs.isEmpty) {
        catalogError = 'The live catalog is empty, showing the bundled list.';
        scholarships = _bundled;
        catalogIsLive = false;
      } else {
        scholarships = snap.docs.map((d) => scholarshipFromFirestore(d.id, d.data())).toList()..sort(_order);
        catalogIsLive = true;
      }
      notifyListeners();
    }, onError: (Object e) {
      catalogError = 'Could not load live scholarships (${_reason(e)}), showing the bundled list.';
      scholarships = _bundled;
      catalogIsLive = false;
      notifyListeners();
    });

    try {
      final doc = await _userDoc.get();
      if (doc.exists) {
        profileFromFirestore(profile, doc.data()!);
      } else {
        profile.displayName = u.displayName ?? '';
        await _userDoc.set({...profileToFirestore(profile), 'createdAt': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      catalogError = 'Could not load your profile (${_reason(e)}).';
    }
    profileLoaded = true;
    notifyListeners();

    _savedSub = _savedCol.snapshots().listen((snap) {
      for (final ch in snap.docChanges) {
        if (ch.doc.metadata.hasPendingWrites) continue; // our own write, already applied locally
        if (ch.type == DocumentChangeType.removed) {
          saved.remove(ch.doc.id);
        } else if (!_savedDebounce.containsKey(ch.doc.id)) {
          saved[ch.doc.id] = savedFromFirestore(ch.doc.id, ch.doc.data()!);
        }
      }
      notifyListeners();
    }, onError: (_) {});
  }

  static int _order(Scholarship a, Scholarship b) {
    if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
    return a.deadline.compareTo(b.deadline);
  }

  static String _reason(Object e) => e is FirebaseException ? (e.code) : '$e';

  // ---------- Auth ----------

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> signUp(String email, String password) =>
      _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Deletes saved scholarships, the profile and the account. Throws
  /// `FirebaseAuthException(requires-recent-login)` when [password] is needed.
  Future<void> deleteAccount({String? password}) async {
    final u = user!;
    if (password != null) {
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
    }
    final batch = _db.batch();
    for (final d in (await _savedCol.get()).docs) {
      batch.delete(d.reference);
    }
    batch.delete(_userDoc);
    await batch.commit();
    await u.delete();
  }

  // ---------- Profile ----------

  Future<void> saveProfile() async {
    notifyListeners();
    if (user == null) return;
    await _userDoc.set(profileToFirestore(profile), SetOptions(merge: true));
  }

  // ---------- Catalog ----------

  List<Scholarship> get active => scholarships.where((s) => s.isActive).toList();

  Scholarship? find(String id) {
    for (final s in scholarships) {
      if (s.id == id) return s;
    }
    return null;
  }

  Scholarship byId(String id) => find(id)!;

  MatchResult match(Scholarship s) => const MatchScorer().score(profile.toAiContext(), s.toAiContext());

  // ---------- Saved ----------

  bool isSaved(String id) => saved.containsKey(id);

  void toggleSaved(String id) {
    if (saved.remove(id) != null) {
      _savedDebounce.remove(id)?.cancel();
      if (user != null) unawaited(_savedCol.doc(id).delete());
    } else {
      final s = SavedScholarship(scholarshipId: id, lastSeenUpdatedAt: find(id)?.updatedAt);
      saved[id] = s;
      if (user != null) {
        unawaited(_savedCol.doc(id).set({
          ...savedToFirestore(s, matchScore: find(id) == null ? null : match(find(id)!).score),
          'savedAt': FieldValue.serverTimestamp(),
        }));
      }
    }
    notifyListeners();
  }

  void setSavedStatus(String id, String status) {
    saved[id]?.status = status;
    updateSaved(id, immediate: true);
  }

  /// Persists a saved scholarship after local edits (checklist, notes, status).
  void updateSaved(String id, {bool immediate = false}) {
    notifyListeners();
    final s = saved[id];
    if (s == null || user == null) return;
    _savedDebounce.remove(id)?.cancel();
    void write() {
      _savedDebounce.remove(id);
      unawaited(_savedCol.doc(id).set(savedToFirestore(s), SetOptions(merge: true)));
    }

    immediate ? write() : _savedDebounce[id] = Timer(const Duration(milliseconds: 800), write);
  }

  /// "Updated" badge (contract §3): scholarship.updatedAt > saved.lastSeenUpdatedAt.
  bool hasUpdate(String id) {
    final s = saved[id], sch = find(id);
    if (s == null || sch?.updatedAt == null || sch!.lastChangeSummary == null) return false;
    return s.lastSeenUpdatedAt == null || sch.updatedAt!.isAfter(s.lastSeenUpdatedAt!);
  }

  void markSeen(String id) {
    final s = saved[id];
    if (s != null && hasUpdate(id)) {
      s.lastSeenUpdatedAt = byId(id).updatedAt;
      updateSaved(id, immediate: true);
    }
  }

  void changed() => notifyListeners();

  @override
  void dispose() {
    _authSub?.cancel();
    _catalogSub?.cancel();
    _savedSub?.cancel();
    for (final t in _savedDebounce.values) {
      t.cancel();
    }
    super.dispose();
  }
}

Future<List<Scholarship>> _loadBundled() async {
  final raw = jsonDecode(await rootBundle.loadString('assets/scholarships.json')) as List;
  return raw.map((e) => _fromSeedJson(e as Map<String, dynamic>)).toList()..sort(AppState._order);
}

/// Parses the Research team's seed format (contract §5) — offline fallback only.
Scholarship _fromSeedJson(Map<String, dynamic> j) {
  DateTime date(String v, {bool endOfDay = false}) {
    if (v.length == 10) {
      // YYYY-MM-DD is WIB (UTC+7): deadline 23:59:59, openDate 00:00.
      return DateTime.parse('${v}T${endOfDay ? '23:59:59' : '00:00:00'}+07:00');
    }
    return DateTime.parse(v);
  }

  List<String> strs(dynamic v) => (v as List? ?? []).cast<String>();
  final verifiedBy = j['verifiedBy'] as String?;
  return Scholarship(
    id: j['id'],
    title: j['title'],
    provider: j['provider'],
    description: j['description'],
    fundingType: j['fundingType'],
    educationLevels: strs(j['educationLevels']),
    eligibleCitizenships: strs(j['eligibleCitizenships']).map((c) => c == 'UK' ? 'GB' : c).toList(),
    hostCountries: strs(j['hostCountries']).map((c) => c == 'UK' ? 'GB' : c).toList(),
    fieldsOfStudy: strs(j['fieldsOfStudy']),
    minGpa: (j['minGpa'] as num?)?.toDouble(),
    languageRequirement: j['languageRequirement'],
    openDate: j['openDate'] == null ? null : date(j['openDate']),
    deadline: date(j['deadline'], endOfDay: true),
    status: j['status'],
    sourceUrl: j['sourceUrl'],
    requirements: [
      for (final r in strs(j['requirements']))
        RequirementItem(
          id: r.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), ''),
          label: r,
        ),
    ],
    benefits: strs(j['benefits']),
    notes: j['notes'],
    verificationStatus: verifiedBy == null || verifiedBy == 'pending-human-review' ? 'pending' : 'verified',
    lastChangeSummary: j['changeSummary'],
    updatedAt: j['lastVerified'] == null ? null : date(j['lastVerified']),
  );
}
