import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:dlwms_mobile/util/bs_dates.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Result of turning a reminder on.
enum ReminderResult { scheduled, tooLate, failed }

/// Reminders the user sets for individual exam terms: a notification the
/// evening before (18:00), or two hours before if that has already passed.
class ExamReminders {
  static const String _key = 'exam_reminders';

  /// Hour of the "day before" reminder.
  static const int eveningHour = 18;

  static Set<String> ids(SharedPreferences prefs) =>
      (prefs.getStringList(_key) ?? const []).toSet();

  static bool isSet(SharedPreferences prefs, ExamTerm term) =>
      ids(prefs).contains(term.id);

  /// When the reminder for [term] fires, or null if it's too late for one.
  static DateTime? reminderTime(ExamTerm term, {DateTime? now}) {
    final at = term.dateTime;
    if (at == null) return null;
    final current = now ?? DateTime.now();

    final dayBefore = DateTime(at.year, at.month, at.day - 1, eveningHour);
    if (dayBefore.isAfter(current)) return dayBefore;

    final twoHoursBefore = at.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(current)) return twoHoursBefore;
    return null;
  }

  static Future<ReminderResult> enable(
    SharedPreferences prefs,
    ExamTerm term,
  ) async {
    final when = reminderTime(term);
    final at = term.dateTime;
    if (when == null || at == null) return ReminderResult.tooLate;

    final sameDay = when.day == at.day;
    final ok = await LocalNotifications.schedule(
      channel: NotifyChannel.podsjetnici,
      key: term.id,
      when: when,
      title: sameDay
          ? 'Ispit za 2 sata: ${term.subject}'
          : 'Sutra ispit: ${term.subject}',
      body: '${_capitalize(BsDates.weekday(at))}, ${DateFormat('dd.MM.').format(at)} '
          'u ${term.timeText}',
      target: const NotificationTarget.tab(AppTab.ispiti),
    );
    if (!ok) return ReminderResult.failed;

    await prefs.setStringList(_key, {...ids(prefs), term.id}.toList());
    return ReminderResult.scheduled;
  }

  static Future<void> disable(SharedPreferences prefs, ExamTerm term) async {
    await LocalNotifications.cancel(NotifyChannel.podsjetnici, term.id);
    await prefs.setStringList(
        _key, ids(prefs).where((id) => id != term.id).toList());
  }

  /// Cancels every reminder, e.g. on logout.
  static Future<void> clear(SharedPreferences prefs) async {
    for (final id in ids(prefs)) {
      await LocalNotifications.cancel(NotifyChannel.podsjetnici, id);
    }
    await prefs.remove(_key);
  }

  static String _capitalize(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
