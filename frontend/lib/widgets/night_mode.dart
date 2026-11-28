import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('lumina/night_mode');

/// Tells Android about Lumina's dark mode setting, so its start-up screen (the plain background
/// before the Flutter loading screen) is dark or light to match on the next launch.
/// Android 12+ only (MainActivity.kt); elsewhere, and in tests, it does nothing.
Future<void> syncNightMode(bool dark) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
  try {
    await _channel.invokeMethod<bool>('set', dark);
  } on Object catch (e) {
    debugPrint('Lumina: could not pass dark mode to Android: $e');
  }
}
