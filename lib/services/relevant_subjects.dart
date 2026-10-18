import 'dart:convert';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/nastava_service.dart';
import 'package:dlwms_mobile/services/uspjeh_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides which subjects an announcement must belong to when
/// "Prikaži samo relevantne obavijesti" is on:
///
/// * every subject of the student's current year of study (both semesters),
///   taken from the subject list on the Nastava page, which DLWMS opens on
///   the current year, and
/// * every subject from any year that has no grade yet ("Nepoloženi ispiti"
///   on the Uspjeh page).
///
/// Announcements without a subject (faculty-wide notices) are always relevant.
///
/// The list is cached in SharedPreferences so the background service can use
/// it too, and refreshed at most every [maxAge].
class RelevantSubjects {
  static const String enabledKey = 'relevant_only';
  static const String _subjectsKey = 'relevant_subjects';
  static const String _updatedKey = 'relevant_subjects_updated';
  static const Duration maxAge = Duration(hours: 12);

  static bool isEnabled(SharedPreferences prefs) =>
      prefs.getBool(enabledKey) ?? false;

  static Future<void> setEnabled(SharedPreferences prefs, bool enabled) =>
      prefs.setBool(enabledKey, enabled);

  /// Lower-cased, whitespace-collapsed name without the trailing `*` DLWMS
  /// adds to some subjects in the grades list.
  static String normalize(String name) => name
      .replaceAll('*', '')
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  /// Downloads the Nastava and Uspjeh pages and builds the subject list.
  static Future<List<String>> fetch(DlwmsClient client) async {
    final nastava =
        NastavaService.parseNastavaPage(await client.fetch(DlwmsClient.nastavaUrl));
    final uspjeh =
        UspjehService.parseUspjehPage(await client.fetch(DlwmsClient.uspjehUrl));

    return combine(
      currentYearSubjects: [
        for (final option in nastava.subjectOptions)
          if (option.value.isNotEmpty) option.label,
      ],
      ungradedSubjects: [
        for (final group in uspjeh.pending)
          for (final exam in group.exams) exam.subject,
      ],
    );
  }

  /// Union of both sources, de-duplicated and sorted for display.
  static List<String> combine({
    required List<String> currentYearSubjects,
    required List<String> ungradedSubjects,
  }) {
    final byKey = <String, String>{};
    for (final name in [...currentYearSubjects, ...ungradedSubjects]) {
      final clean = name.replaceAll('*', '').trim();
      if (clean.isEmpty) continue;
      byKey.putIfAbsent(normalize(clean), () => clean);
    }
    final names = byKey.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Cached subject names, or null if they were never loaded.
  static List<String>? cached(SharedPreferences prefs) {
    final raw = prefs.getString(_subjectsKey);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  static DateTime? lastUpdated(SharedPreferences prefs) {
    final millis = prefs.getInt(_updatedKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool isStale(SharedPreferences prefs) {
    final updated = lastUpdated(prefs);
    return cached(prefs) == null ||
        updated == null ||
        DateTime.now().difference(updated) > maxAge;
  }

  /// Returns the cached list, refreshing it first when stale (or [force]).
  /// Falls back to the stale cache if DLWMS can't be reached.
  static Future<List<String>?> load(
    DlwmsClient client,
    SharedPreferences prefs, {
    bool force = false,
  }) async {
    await prefs.reload();
    if (!force && !isStale(prefs)) return cached(prefs);

    try {
      final names = await fetch(client);
      if (names.isNotEmpty) {
        await prefs.setString(_subjectsKey, jsonEncode(names));
        await prefs.setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
      }
      return names.isEmpty ? cached(prefs) : names;
    } catch (_) {
      return cached(prefs);
    }
  }

  static Future<void> clear(SharedPreferences prefs) async {
    await prefs.remove(_subjectsKey);
    await prefs.remove(_updatedKey);
  }

  static bool isRelevant(DlwmsNotification notification, Set<String> keys) =>
      notification.subject.trim().isEmpty ||
      keys.contains(normalize(notification.subject));

  /// Applies the filter. With no subject list available, nothing is hidden,
  /// so a failed load never makes announcements disappear.
  static List<DlwmsNotification> filter(
    List<DlwmsNotification> notifications,
    List<String>? subjects,
  ) {
    if (subjects == null || subjects.isEmpty) return notifications;
    final keys = subjects.map(normalize).toSet();
    return notifications.where((n) => isRelevant(n, keys)).toList();
  }
}
