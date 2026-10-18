import 'package:shared_preferences/shared_preferences.dart';

enum CheckResult { ok, authFailed, error }

/// Outcome of the most recent check for new announcements. Written by
/// whichever isolate ran the check and shown in the settings sheet (the
/// background service no longer shows a visible notification).
class CheckStatus {
  const CheckStatus({
    required this.time,
    required this.result,
    required this.newCount,
  });

  static const String _timeKey = 'last_check_time';
  static const String _resultKey = 'last_check_result';
  static const String _newKey = 'last_check_new';

  final DateTime time;
  final CheckResult result;
  final int newCount;

  static Future<void> save(
    SharedPreferences prefs,
    CheckResult result, {
    int newCount = 0,
  }) async {
    await prefs.setInt(_timeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(_resultKey, result.name);
    await prefs.setInt(_newKey, newCount);
  }

  static CheckStatus? read(SharedPreferences prefs) {
    final millis = prefs.getInt(_timeKey);
    if (millis == null) return null;
    return CheckStatus(
      time: DateTime.fromMillisecondsSinceEpoch(millis),
      result: CheckResult.values.firstWhere(
        (r) => r.name == prefs.getString(_resultKey),
        orElse: () => CheckResult.ok,
      ),
      newCount: prefs.getInt(_newKey) ?? 0,
    );
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_timeKey);
    await prefs.remove(_resultKey);
    await prefs.remove(_newKey);
  }
}
