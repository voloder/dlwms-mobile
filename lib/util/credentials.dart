import 'package:shared_preferences/shared_preferences.dart';

/// Keys shared by the UI isolate and the background service.
class PrefKeys {
  static const String username = 'username';
  static const String password = 'password';
  static const String backgroundCheck = 'background_check_enabled';
  static const String batteryPromptShown = 'battery_prompt_shown';
}

class Credentials {
  const Credentials(this.username, this.password);

  final String username;
  final String password;

  static Credentials? read(SharedPreferences prefs) {
    final username = prefs.getString(PrefKeys.username);
    final password = prefs.getString(PrefKeys.password);
    if (username == null || password == null) return null;
    if (username.isEmpty || password.isEmpty) return null;
    return Credentials(username, password);
  }
}
