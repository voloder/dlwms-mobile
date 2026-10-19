import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/relevant_subjects.dart';
import 'package:dlwms_mobile/services/seen_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Detects announcements ("Obavijesti") that haven't been seen before and
/// raises a local notification for each one.
class ObavijestiWatcher {
  static const String seenKey = 'obavijesti_seen_ids';

  /// At most this many individual alerts per check; DLWMS shows 10 per page.
  static const int maxAlertsPerCheck = 5;

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

    for (final notification in toAlert.take(maxAlertsPerCheck)) {
      await LocalNotifications.showNewNotification(notification);
    }
    return toAlert;
  }

  /// Returns items from [current] that weren't seen before and remembers them.
  static Future<List<DlwmsNotification>> detectNew(
    List<DlwmsNotification> current,
    SharedPreferences prefs,
  ) =>
      SeenStore.detectNew(prefs, seenKey, current, (n) => n.id);

  static Future<void> reset(SharedPreferences prefs) =>
      SeenStore.clear(prefs, seenKey);
}
