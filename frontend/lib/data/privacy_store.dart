import 'package:shared_preferences/shared_preferences.dart';

/// Remembers, on this phone, a "cloud AI off" choice that the account does not have yet
/// (its save is pending or failed). It outlives an app restart, so the account's older
/// "on" can never send a question to the cloud after the student turned cloud AI off here.
abstract interface class LocalPrivacyStore {
  Future<bool> unsavedCloudOff(String uid);
  Future<void> setUnsavedCloudOff(String uid, bool value);
}

/// Kept in memory only: for tests and for running without the plugin.
class MemoryPrivacyStore implements LocalPrivacyStore {
  final _off = <String>{};

  @override
  Future<bool> unsavedCloudOff(String uid) async => _off.contains(uid);

  @override
  Future<void> setUnsavedCloudOff(String uid, bool value) async => value ? _off.add(uid) : _off.remove(uid);
}

/// The app's store, in the platform's shared preferences.
class SharedPrefsPrivacyStore implements LocalPrivacyStore {
  final _prefs = SharedPreferencesAsync();

  static String _key(String uid) => 'lumina.unsavedCloudOff.$uid';

  @override
  Future<bool> unsavedCloudOff(String uid) async => await _prefs.getBool(_key(uid)) ?? false;

  @override
  Future<void> setUnsavedCloudOff(String uid, bool value) =>
      value ? _prefs.setBool(_key(uid), true) : _prefs.remove(_key(uid));
}
