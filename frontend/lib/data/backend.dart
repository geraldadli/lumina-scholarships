import '../models/saved_scholarship.dart';
import '../models/scholarship.dart';
import '../models/user_profile.dart';

class AuthUser {
  const AuthUser({required this.uid, this.email, this.displayName, this.usesPassword = false});

  final String uid;
  final String? email;
  final String? displayName;

  /// Signed up with email + password (confirm with the password), otherwise Google
  /// (confirm by signing in with Google again).
  final bool usesPassword;
}

/// A sign-in / account error with a message that is safe to show.
class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.requiresRecentLogin = false});

  final String message;
  final bool requiresRecentLogin;

  @override
  String toString() => message;
}

/// Everything the app reads and writes. Screens never touch Firebase directly.
///
/// [FirebaseBackend] is the real one (Auth + Firestore, docs/firestore-contract.md).
/// [DemoBackend] runs on the bundled research data when google-services.json is missing.
abstract interface class LuminaBackend {
  bool get isDemo;

  Stream<AuthUser?> authState();
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail(String email, String password);
  Future<void> createAccountWithEmail(String email, String password);

  /// Emails a password-reset link. Succeeds even when no account uses [email], so the app
  /// never reveals which emails are registered.
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();

  /// Confirms the student first ([password] for email accounts, a Google sign-in otherwise),
  /// and only then deletes saved scholarships, the profile document and the auth user.
  /// A wrong password or a cancelled confirmation throws [AuthFailure] with nothing deleted.
  Future<void> deleteAccount(String uid, {String? password});

  /// `null` when `users/{uid}` does not exist yet (first sign-in → onboarding).
  Stream<UserProfile?> profile(String uid);
  Future<void> saveProfile(String uid, UserProfile profile, {required bool isNew});

  /// The whole catalog ordered by deadline (< 100 docs); filtering happens on the client.
  Stream<List<Scholarship>> scholarships();

  Stream<Map<String, SavedScholarship>> saved(String uid);
  Future<void> save(String uid, Scholarship s, {double? matchScore, String status = 'saved', List<ChecklistEntry> checklist = const []});
  Future<void> updateSaved(String uid, String scholarshipId, SavedPatch patch);
  Future<void> unsave(String uid, String scholarshipId);
}
