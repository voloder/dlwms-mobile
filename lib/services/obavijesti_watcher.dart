import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/relevant_subjects.dart';
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
  /// local notifications for new items. Returns the items that were alerted
  /// (new and, if the filter is on, relevant).
  static Future<List<DlwmsNotification>> checkForNew(
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final page = await client.fetch(DlwmsClient.homeUrl);
    final current = NotificationService.parseNotifications(page);
    final fresh = await detectNew(current, prefs);
    return alert(fresh, client, prefs);
  }

  /// Shows a local notification for each of [fresh], skipping irrelevant
  /// subjects when "Prikaži samo relevantne obavijesti" is on. Skipped items
  /// stay marked as seen, so turning the filter off later doesn't replay them.
  static Future<List<DlwmsNotification>> alert(
    List<DlwmsNotification> fresh,
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    if (fresh.isEmpty) return const [];

    var toAlert = fresh;
    if (RelevantSubjects.isEnabled(prefs)) {
      final subjects = await RelevantSubjects.load(client, prefs);
      toAlert = RelevantSubjects.filter(fresh, subjects);
    }

    for (final notification in toAlert.take(_maxAlertsPerCheck)) {
      await LocalNotifications.showNewNotification(notification);
    }
    return toAlert;
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
