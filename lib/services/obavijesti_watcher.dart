import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects announcements ("Obavijesti") that haven't been seen before and
/// raises a local notification for each one.
///
/// The set of seen ids lives in SharedPreferences so the UI isolate and the
/// background service agree on what is new.
class ObavijestiWatcher {
  static const String seenKey = 'obavijesti_seen_ids';
  static const int _maxRemembered = 300;

  /// At most this many individual alerts per check; DLWMS shows 10 per page.
  static const int _maxAlertsPerCheck = 5;

  /// Fetches the home page, compares it with what was seen before and shows
  /// local notifications for new items. Returns the new items.
  static Future<List<DlwmsNotification>> checkForNew(
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final page = await client.fetch(DlwmsClient.homeUrl);
    final current = NotificationService.parseNotifications(page);
    final fresh = await detectNew(current, prefs);

    for (final notification in fresh.take(_maxAlertsPerCheck)) {
      await LocalNotifications.showNewNotification(notification);
    }
    return fresh;
  }

  /// Returns items from [current] that weren't seen before and remembers them.
  ///
  /// The very first run only records a baseline, so installing the app (or
  /// logging in) doesn't produce a burst of alerts for old announcements.
  static Future<List<DlwmsNotification>> detectNew(
    List<DlwmsNotification> current,
    SharedPreferences prefs,
  ) async {
    if (current.isEmpty) return const [];

    await prefs.reload();
    final stored = prefs.getStringList(seenKey);
    final currentIds = current.map((n) => n.id).toList();

    if (stored == null) {
      await prefs.setStringList(seenKey, currentIds);
      return const [];
    }

    final seen = stored.toSet();
    final fresh = current.where((n) => !seen.contains(n.id)).toList();

    if (fresh.isNotEmpty) {
      final merged = <String>[
        ...currentIds,
        ...stored.where((id) => !currentIds.contains(id)),
      ].take(_maxRemembered).toList();
      await prefs.setStringList(seenKey, merged);
    }

    return fresh;
  }

  /// Marks everything in [current] as seen without alerting.
  static Future<void> markSeen(
    List<DlwmsNotification> current,
    SharedPreferences prefs,
  ) async {
    await detectNew(current, prefs);
  }

  static Future<void> reset(SharedPreferences prefs) => prefs.remove(seenKey);
}
