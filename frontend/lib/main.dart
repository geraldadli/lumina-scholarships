import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/backend.dart';
import 'data/demo_backend.dart';
import 'data/firebase_backend.dart';
import 'data/privacy_store.dart';
import 'design/appearance.dart';
import 'state/app_controller.dart';

/// Optional App Check debug token that is already registered in the Firebase Console, given at
/// build time so it never lands in the (public) repo:
///   flutter build apk --release --dart-define-from-file=../_local/app_check.json
/// with `{"APP_CHECK_DEBUG_TOKEN": "<token>"}`.
/// - Debug build without it: the device makes its own token and prints it to logcat
///   ("Enter this debug secret into the allow list").
/// - Release build with it: uses this token instead of Play Integrity. The judge APK needs this,
///   because Play Integrity rejects an APK installed outside Google Play (cloud AI then shows
///   "App not verified"). The hackathon accepts App Check debug tokens in submissions.
/// - Release build without it: Play Integrity.
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await _createBackend();
  final appearance = await AppearanceController.load();
  // The cloud AI "off" chosen on this phone survives a restart even before the account has it.
  runApp(LuminaApp(
    controller: AppController(backend: backend, ai: HybridAi(), privacyStore: SharedPrefsPrivacyStore()),
    appearance: appearance,
  ));
}

/// Live Firebase when android/app/google-services.json is installed, demo data otherwise.
Future<LuminaBackend> _createBackend() async {
  try {
    await Firebase.initializeApp();
  } on Object catch (e) {
    debugPrint('Lumina: Firebase not configured ($e). Running in demo mode.');
    return DemoBackend.fromAsset();
  }
  try {
    // AI Logic enforces App Check. See _appCheckDebugToken for which provider each build uses.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode || _appCheckDebugToken != ''
          ? const AndroidDebugProvider(debugToken: _appCheckDebugToken == '' ? null : _appCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
    );
  } on Object catch (e) {
    debugPrint('Lumina: App Check activation failed: $e');
  }
  return FirebaseBackend();
}
