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
/// The user can edit the result: subjects they add or remove are kept as
/// separate overrides, so the automatic list can still refresh underneath.
///
/// Everything lives in SharedPreferences so the background service can use
/// it too. The automatic list is refreshed at most every [maxAge].
class RelevantSubjects {
  static const String enabledKey = 'relevant_only';
  static const String _subjectsKey = 'relevant_subjects';
  static const String _updatedKey = 'relevant_subjects_updated';
  static const String _addedKey = 'relevant_subjects_added';
  static const String _removedKey = 'relevant_subjects_removed';
  static const String _knownKey = 'relevant_subjects_known';
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

  /// Downloads the Nastava and Uspjeh pages and builds the automatic list,
  /// plus every subject seen there (offered when adding one by hand).
  static Future<({List<String> relevant, List<String> known})> fetch(
      DlwmsClient client) async {
    final nastava =
        NastavaService.parseNastavaPage(await client.fetch(DlwmsClient.nastavaUrl));
    final uspjeh =
        UspjehService.parseUspjehPage(await client.fetch(DlwmsClient.uspjehUrl));

    final currentYear = [
      for (final option in nastava.subjectOptions)
        if (option.value.isNotEmpty) option.label,
    ];
    final ungraded = [
      for (final group in uspjeh.pending)
        for (final exam in group.exams) exam.subject,
    ];
    final passed = [
      for (final group in uspjeh.passed)
        for (final exam in group.exams) exam.subject,
    ];

    return (
      relevant: combine(
          currentYearSubjects: currentYear, ungradedSubjects: ungraded),
      known: combine(
          currentYearSubjects: [...currentYear, ...passed],
          ungradedSubjects: ungraded),
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

  static List<String>? _readList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _writeList(
          SharedPreferences prefs, String key, Iterable<String> values) =>
      prefs.setString(key, jsonEncode(values.toList()));

  /// The automatic list from DLWMS, or null if it was never loaded.
  static List<String>? automatic(SharedPreferences prefs) =>
      _readList(prefs, _subjectsKey);

  /// Subjects the user added by hand.
  static List<String> added(SharedPreferences prefs) =>
      _readList(prefs, _addedKey) ?? const [];

  /// Normalised names of automatic subjects the user removed.
  static Set<String> removed(SharedPreferences prefs) =>
      (_readList(prefs, _removedKey) ?? const []).toSet();

  static bool hasEdits(SharedPreferences prefs) =>
      added(prefs).isNotEmpty || removed(prefs).isNotEmpty;

  /// The list in effect: automatic minus removed plus added. Null only when
  /// nothing was ever loaded or added.
  static List<String>? cached(SharedPreferences prefs) {
    final auto = automatic(prefs);
    final extra = added(prefs);
    if (auto == null && extra.isEmpty) return null;

    final gone = removed(prefs);
    return combine(
      currentYearSubjects: [
        for (final name in auto ?? const <String>[])
          if (!gone.contains(normalize(name))) name,
      ],
      ungradedSubjects: extra,
    );
  }

  /// Whether [name] is in the list only because the user added it.
  static bool isAddedByUser(SharedPreferences prefs, String name) {
    final key = normalize(name);
    return added(prefs).any((n) => normalize(n) == key);
  }

  /// Subjects that could be added: everything seen on DLWMS (plus [extra],
  /// e.g. subjects of loaded announcements) that isn't in the list yet.
  static List<String> candidates(SharedPreferences prefs,
      {Iterable<String> extra = const []}) {
    final current = (cached(prefs) ?? const []).map(normalize).toSet();
    return combine(
      currentYearSubjects: [
        ...?_readList(prefs, _knownKey),
        ...?automatic(prefs),
      ],
      ungradedSubjects: extra.toList(),
    ).where((n) => !current.contains(normalize(n))).toList();
  }

  static Future<void> add(SharedPreferences prefs, String name) async {
    final clean = name.replaceAll('*', '').trim();
    if (clean.isEmpty) return;
    final key = normalize(clean);

    final gone = removed(prefs);
    if (gone.remove(key)) await _writeList(prefs, _removedKey, gone);

    final inAuto = (automatic(prefs) ?? const []).any((n) => normalize(n) == key);
    final extra = added(prefs);
    if (!inAuto && !extra.any((n) => normalize(n) == key)) {
      await _writeList(prefs, _addedKey, [...extra, clean]);
    }
  }

  static Future<void> remove(SharedPreferences prefs, String name) async {
    final key = normalize(name);
    final extra = added(prefs);
    if (extra.any((n) => normalize(n) == key)) {
      await _writeList(
          prefs, _addedKey, extra.where((n) => normalize(n) != key));
    }
    if ((automatic(prefs) ?? const []).any((n) => normalize(n) == key)) {
      await _writeList(prefs, _removedKey, {...removed(prefs), key});
    }
  }

  /// Drops the user's changes and goes back to the automatic list.
  static Future<void> resetEdits(SharedPreferences prefs) async {
    await prefs.remove(_addedKey);
    await prefs.remove(_removedKey);
  }

  static DateTime? lastUpdated(SharedPreferences prefs) {
    final millis = prefs.getInt(_updatedKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  static bool isStale(SharedPreferences prefs) {
    final updated = lastUpdated(prefs);
    return automatic(prefs) == null ||
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
      final result = await fetch(client);
      if (result.relevant.isNotEmpty) {
        await _writeList(prefs, _subjectsKey, result.relevant);
        await _writeList(prefs, _knownKey, result.known);
        await prefs.setInt(_updatedKey, DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {
      // Keep using the cached list.
    }
    return cached(prefs);
  }

  /// Forgets the downloaded lists. The user's changes are kept unless
  /// [includeEdits] (when a different student logs in).
  static Future<void> clear(SharedPreferences prefs,
      {bool includeEdits = true}) async {
    await prefs.remove(_subjectsKey);
    await prefs.remove(_updatedKey);
    await prefs.remove(_knownKey);
    if (includeEdits) await resetEdits(prefs);
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
