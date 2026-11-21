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
      providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
    );
  } on Object catch (e) {
    debugPrint('Lumina: App Check activation failed: $e');
  }
  return FirebaseBackend();
}
