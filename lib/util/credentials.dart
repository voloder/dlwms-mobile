import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keys shared by the UI isolate and the background service.
class PrefKeys {
  static const String username = 'username';

  /// Plain-text password used by versions before 0.3; migrated on first read.
  static const String legacyPassword = 'password';

  static const String backgroundCheck = 'background_check_enabled';
  static const String batteryPromptShown = 'battery_prompt_shown';
}

class Credentials {
  const Credentials(this.username, this.password);

  final String username;
  final String password;
}

/// Stores the login. The index number stays in SharedPreferences; the
/// password goes to [FlutterSecureStorage], which encrypts it with a key kept
/// in the Android Keystore (Keychain on iOS).
class CredentialStore {
  static const String _passwordKey = 'dlwms_password';
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  /// Saved credentials, or null if the user isn't logged in. Moves a password
  /// saved in plain text by an older version into secure storage.
  static Future<Credentials?> read(SharedPreferences prefs) async {
    final username = prefs.getString(PrefKeys.username);
    if (username == null || username.isEmpty) return null;

    final legacy = prefs.getString(PrefKeys.legacyPassword);
    if (legacy != null) {
      if (legacy.isNotEmpty) {
        await _secure.write(key: _passwordKey, value: legacy);
      }
      await prefs.remove(PrefKeys.legacyPassword);
    }

    String? password;
    try {
      password = await _secure.read(key: _passwordKey);
    } catch (_) {
      // Unreadable (e.g. the Keystore key was lost after a restore): the
      // user simply logs in again.
      password = null;
    }
    if (password == null || password.isEmpty) return null;
    return Credentials(username, password);
  }

  static Future<void> save(
    SharedPreferences prefs,
    String username,
    String password,
  ) async {
    await prefs.setString(PrefKeys.username, username);
    await _secure.write(key: _passwordKey, value: password);
    await prefs.remove(PrefKeys.legacyPassword);
  }

  /// Forgets the password; the index number is kept to prefill the login.
  static Future<void> clearPassword(SharedPreferences prefs) async {
    await prefs.remove(PrefKeys.legacyPassword);
    try {
      await _secure.delete(key: _passwordKey);
    } catch (_) {}
  }
}
