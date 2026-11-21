import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hybrid_ai/hybrid_ai.dart';
import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'data/backend.dart';
import 'data/demo_backend.dart';
import 'data/firebase_backend.dart';
import 'state/app_controller.dart';

/// Optional App Check debug token that is already registered in the Firebase Console, given at
/// build time so it never lands in the (public) repo:
///   flutter build apk --debug --dart-define-from-file=../_local/app_check.json
/// with `{"APP_CHECK_DEBUG_TOKEN": "<token>"}`. Empty: the device makes its own token and prints
/// it to logcat ("Enter this debug secret into the allow list").
const _appCheckDebugToken = String.fromEnvironment('APP_CHECK_DEBUG_TOKEN');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final backend = await _createBackend();
  runApp(LuminaApp(controller: AppController(backend: backend, ai: HybridAi())));
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
    // AI Logic enforces App Check. Debug builds print a debug token to logcat
    // ("Enter this debug secret into the allow list") to register in the Firebase Console.
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider(debugToken: _appCheckDebugToken == '' ? null : _appCheckDebugToken)
          : const AndroidPlayIntegrityProvider(),
    );
  } on Object catch (e) {
    debugPrint('Lumina: App Check activation failed: $e');
  }
  return FirebaseBackend();
}
