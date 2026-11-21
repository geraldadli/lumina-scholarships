import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/saved_scholarship.dart';
import '../models/scholarship.dart';
import '../models/user_profile.dart';
import '../util/format.dart';
import 'backend.dart';

/// Firebase Auth + Firestore, following docs/firestore-contract.md and firestore.rules.
class FirebaseBackend implements LuminaBackend {
  FirebaseBackend({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  bool get isDemo => false;

  DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _saved(String uid) => _user(uid).collection('saved_scholarships');

  // ───────────── Auth ─────────────

  @override
  Stream<AuthUser?> authState() => _auth.authStateChanges().map(
        (u) => u == null
            ? null
            : AuthUser(
                uid: u.uid,
                email: u.email,
                displayName: u.displayName,
                usesPassword: u.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID),
              ),
      );

  bool _googleReady = false;

  /// Native Google account picker (Android Credential Manager), turned into a Firebase credential.
  ///
  /// Not `signInWithProvider`: that opens Google's page in a browser tab, and on some phones
  /// (seen on a Realme) closing it without picking an account never answers. The pending
  /// sign-in then blocks every retry with "A headful operation is already in progress".
  /// The native picker always answers, including "canceled".
  /// Setup: the web OAuth client (`client_type: 3`) in google-services.json, plus this build's
  /// SHA-1 registered for com.lumina.app.
  Future<AuthCredential> _googleCredential() async {
    final google = GoogleSignIn.instance;
    if (!_googleReady) {
      await google.initialize();
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await google.authenticate();
    } on GoogleSignInException catch (e) {
      throw switch (e.code) {
        GoogleSignInExceptionCode.canceled => const AuthFailure('Sign-in was cancelled.', cancelled: true),
        GoogleSignInExceptionCode.clientConfigurationError || GoogleSignInExceptionCode.providerConfigurationError =>
          const AuthFailure('Google sign-in is not set up for this app yet. Use email for now.'),
        GoogleSignInExceptionCode.uiUnavailable => const AuthFailure('Google sign-in is not available on this phone.'),
        _ => const AuthFailure('Google sign-in failed. Try again.'),
      };
    }
    final idToken = account.authentication.idToken;
    if (idToken == null) throw const AuthFailure('Google sign-in failed. Try again.');
    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> signInWithGoogle() async {
    final credential = await _googleCredential();
    await _wrap(() => _auth.signInWithCredential(credential));
  }

  @override
  Future<void> signInWithEmail(String email, String password) =>
      _wrap(() => _auth.signInWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> createAccountWithEmail(String email, String password) =>
      _wrap(() => _auth.createUserWithEmailAndPassword(email: email.trim(), password: password));

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      // Same answer whether or not the account exists (no account enumeration).
      if (e.code == 'user-not-found') return;
      throw AuthFailure(_authMessage(e));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();
    // Forget the chosen Google account too, so the next sign-in offers the account picker.
    if (_googleReady) {
      try {
        await GoogleSignIn.instance.signOut();
      } on Object catch (_) {}
    }
  }

  @override
  Future<void> deleteAccount(String uid, {String? password}) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) throw const AuthFailure('You are not signed in.');

    // Confirm who this is BEFORE touching any data. Firebase only deletes an auth user after a
    // recent sign-in; deleting Firestore first would leave an empty account behind if it refused.
    final usesPassword = user.providerData.any((p) => p.providerId == EmailAuthProvider.PROVIDER_ID);
    if (usesPassword) {
      if (password == null || password.isEmpty || user.email == null) {
        throw const AuthFailure('Enter your password to confirm.');
      }
      await _wrap(() => user.reauthenticateWithCredential(
            EmailAuthProvider.credential(email: user.email!, password: password),
          ));
    } else {
      final credential = await _googleCredential();
      await _wrap(() => user.reauthenticateWithCredential(credential));
    }

    final saved = await _saved(uid).get();
    final batch = _db.batch();
    for (final d in saved.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_user(uid));
    await batch.commit();
    await _wrap(user.delete);
  }

  Future<void> _wrap(Future<Object?> Function() call) async {
    try {
      await call();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_authMessage(e), requiresRecentLogin: e.code == 'requires-recent-login');
    }
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'That email address is not valid.',
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email. Sign in instead.',
        'weak-password' => 'Use a password with at least 6 characters.',
        'network-request-failed' => 'No connection. Check your internet and try again.',
        'too-many-requests' => 'Too many attempts. Try again in a few minutes.',
        'missing-email' => 'Enter your email address first.',
        'requires-recent-login' => 'For your security, sign in again before deleting your account.',
        'web-context-canceled' || 'canceled' => 'Sign-in was cancelled.',
        'operation-not-allowed' => 'This sign-in method is not enabled yet.',
        'user-mismatch' => 'That is a different account. Confirm with the account you are signed in with.',
        _ => e.message ?? 'Sign-in failed. Try again.',
      };

  // ───────────── users/{uid} ─────────────

  @override
  Stream<UserProfile?> profile(String uid) => _user(uid).snapshots().map((d) {
        final data = d.data();
        return data == null ? null : UserProfile.fromMap(data);
      });

  @override
  Future<void> saveProfile(String uid, UserProfile p, {required bool isNew}) {
    // set(merge) + FieldValue.delete() for cleared optional fields: the rules reject
    // `educationLevel: null`, `citizenship: null` etc., so they must be absent instead.
    Object opt(Object? v) => v ?? FieldValue.delete();
    final data = <String, Object>{
      'displayName': p.displayName.trim(),
      'educationLevel': opt(p.educationLevel),
      'currentEducationLevel': opt(p.currentEducationLevel),
      'citizenship': opt(normCountry(p.citizenship)),
      'targetCountries': p.targetCountries.take(30).toList(),
      'fieldsOfStudy': p.fieldsOfStudy.take(20).toList(),
      'gpa': opt(p.gpa),
      // merge: true merges nested maps key by key, so a cleared score must be deleted explicitly.
      'languageScores': {
        for (final k in LanguageScores.keys) k: p.languageScores.toMap()[k] ?? FieldValue.delete(),
      },
      'fundingPreference': opt(p.fundingPreference),
      'privacy': {'cloudAiAllowed': p.cloudAiAllowed},
      'onboardingCompleted': p.onboardingCompleted,
      'updatedAt': FieldValue.serverTimestamp(),
      if (isNew) 'createdAt': FieldValue.serverTimestamp(),
    };
    return _user(uid).set(data, SetOptions(merge: true));
  }

  // ───────────── scholarships ─────────────

  @override
  Stream<List<Scholarship>> scholarships() => _db
      .collection('scholarships')
      .orderBy('deadline')
      .snapshots()
      .map((q) => q.docs.map((d) => scholarshipFromFirestore(d.id, d.data())).toList());

  // ───────────── saved_scholarships ─────────────

  @override
  Stream<Map<String, SavedScholarship>> saved(String uid) => _saved(uid).snapshots().map(
        (q) => {for (final d in q.docs) d.id: _savedFromFirestore(d.id, d.data())},
      );

  @override
  Future<void> save(
    String uid,
    Scholarship s, {
    double? matchScore,
    String status = 'saved',
    List<ChecklistEntry> checklist = const [],
  }) =>
      _saved(uid).doc(s.id).set({
        'scholarshipId': s.id, // must equal the document id (rules)
        'status': status,
        'matchScore': matchScore?.clamp(0.0, 1.0),
        'checklist': [for (final c in checklist.take(50)) c.toMap()],
        'notes': '',
        'lastSeenUpdatedAt': s.updatedAt == null ? null : Timestamp.fromDate(s.updatedAt!),
        'savedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch) => _saved(uid).doc(scholarshipId).update({
        if (patch.status != null) 'status': patch.status!,
        if (patch.checklist != null) 'checklist': [for (final c in patch.checklist!.take(50)) c.toMap()],
        if (patch.notes != null) 'notes': clipUtf16(patch.notes!, maxNotesLength),
        if (patch.lastSeenUpdatedAt != null) 'lastSeenUpdatedAt': Timestamp.fromDate(patch.lastSeenUpdatedAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> unsave(String uid, String scholarshipId) => _saved(uid).doc(scholarshipId).delete();
}

DateTime? _time(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime t => t,
      String s => DateTime.tryParse(s),
      _ => null,
    };

List<String> _strings(Object? v) => v is List ? v.whereType<String>().toList() : const [];

/// Defensive parser for `scholarships/{id}`: a missing optional field never crashes the list.
Scholarship scholarshipFromFirestore(String id, Map<String, dynamic> d) => Scholarship(
      id: id,
      title: d['title'] as String? ?? '',
      provider: d['provider'] as String? ?? '',
      description: d['description'] as String?,
      fundingType: d['fundingType'] as String? ?? 'full',
      educationLevels: _strings(d['educationLevels']),
      eligibleCitizenships: _strings(d['eligibleCitizenships']).map(normCountry).whereType<String>().toList(),
      hostCountries: _strings(d['hostCountries']).map(normCountry).whereType<String>().toList(),
      fieldsOfStudy: _strings(d['fieldsOfStudy']),
      minGpa: (d['minGpa'] as num?)?.toDouble(),
      languageRequirement: d['languageRequirement'] as String?,
      openDate: _time(d['openDate']),
      deadline: _time(d['deadline']),
      status: d['status'] as String? ?? 'active',
      isUrgent: d['isUrgent'] == true,
      requirements: [
        for (final r in (d['requirements'] as List? ?? const []))
          if (r is Map && r['label'] is String)
            Requirement(id: r['id'] as String? ?? slugify(r['label'] as String), label: r['label'] as String)
          else if (r is String)
            Requirement(id: slugify(r), label: r),
      ],
      benefits: _strings(d['benefits']),
      sourceUrl: d['sourceUrl'] as String? ?? '',
      notes: d['notes'] as String?,
      verified: d['verificationStatus'] == 'verified',
      lastVerifiedAt: _time(d['lastVerifiedAt']),
      lastChangeSummary: d['lastChangeSummary'] as String?,
      updatedAt: _time(d['updatedAt']),
      lastCheckedAt: _time(d['lastCheckedAt']),
    );

SavedScholarship _savedFromFirestore(String id, Map<String, dynamic> d) => SavedScholarship(
      scholarshipId: d['scholarshipId'] as String? ?? id,
      status: d['status'] as String? ?? 'saved',
      matchScore: (d['matchScore'] as num?)?.toDouble(),
      checklist: [
        for (final c in (d['checklist'] as List? ?? const []))
          if (c is Map) ChecklistEntry.fromMap(c.cast<String, dynamic>()),
      ],
      notes: d['notes'] as String? ?? '',
      lastSeenUpdatedAt: _time(d['lastSeenUpdatedAt']),
      savedAt: _time(d['savedAt']),
    );
