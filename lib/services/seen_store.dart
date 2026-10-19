import 'package:shared_preferences/shared_preferences.dart';

/// Remembers which items of a list have been seen, so a later check can tell
/// what is new. Shared by the UI isolate and the background service through
/// SharedPreferences.
class SeenStore {
  static const int _maxRemembered = 400;

  /// Returns the items of [current] whose id isn't stored under [key] yet,
  /// and remembers them.
  ///
  /// The first run for a key only records a baseline, so logging in or
  /// turning on a new kind of alert doesn't flood the user with old items.
  /// An empty [current] (e.g. a failed load) never resets the baseline.
  static Future<List<T>> detectNew<T>(
    SharedPreferences prefs,
    String key,
    List<T> current,
    String Function(T item) idOf,
  ) async {
    if (current.isEmpty) return const [];

    await prefs.reload();
    final stored = prefs.getStringList(key);
    final currentIds = current.map(idOf).toList();

    if (stored == null) {
      await prefs.setStringList(key, currentIds);
      return const [];
    }

    final seen = stored.toSet();
    final fresh = current.where((item) => !seen.contains(idOf(item))).toList();

    if (fresh.isNotEmpty) {
      final currentSet = currentIds.toSet();
      final merged = <String>[
        ...currentIds,
        ...stored.where((id) => !currentSet.contains(id)),
      ].take(_maxRemembered).toList();
      await prefs.setStringList(key, merged);
    }
    return fresh;
  }

  static Future<void> clear(SharedPreferences prefs, String key) =>
      prefs.remove(key);
}
