import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/models/uspjeh.dart';
import 'package:dlwms_mobile/provider/ispiti_provider.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/ispiti_service.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
import 'package:dlwms_mobile/services/seen_store.dart';
import 'package:dlwms_mobile/services/uspjeh_service.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kinds of alerts the user can switch on or off in Settings.
enum AlertKind {
  obavijesti('Nove obavijesti', 'Obavijesti sa početne stranice'),
  ocjene('Nove ocjene', 'Kada se na Uspjehu pojavi nova ocjena'),
  testovi('Testovi', 'Aktivan test i rezultat testa'),
  rokovi('Ispitni rokovi', 'Novi ispitni rok ili termin ispita'),
  dokumenti('Novi dokumenti', 'Dokumenti iz tvojih predmeta');

  const AlertKind(this.title, this.description);

  final String title;
  final String description;

  String get _prefKey => 'alert_$name';

  bool isEnabled(SharedPreferences prefs) => prefs.getBool(_prefKey) ?? true;

  Future<void> setEnabled(SharedPreferences prefs, bool value) =>
      prefs.setBool(_prefKey, value);
}

/// Runs all change checks against DLWMS and raises local notifications.
///
/// The home page (announcements and the "Zadnji dokumenti" sidebar) is
/// checked every time. Grades, tests and exam terms need three more pages,
/// so they are checked at most every [extendedInterval].
class DlwmsWatchers {
  static const Duration extendedInterval = Duration(minutes: 15);
  static const String _lastExtendedKey = 'last_extended_check';

  static const String _documentsKey = 'seen_documents';
  static const String _gradesKey = 'seen_grades';
  static const String _testResultsKey = 'seen_test_results';
  static const String _activeTestsKey = 'seen_active_tests';
  static const String _periodsKey = 'seen_exam_periods';
  static const String _termsKey = 'seen_exam_terms';

  static const int _maxPerKind = 5;

  /// Checks everything that is due and returns how many alerts were shown.
  /// Pass [homePage] when the caller already loaded `default.aspx`.
  static Future<int> runChecks(
    DlwmsClient client,
    SharedPreferences prefs, {
    DlwmsPage? homePage,
    bool forceExtended = false,
  }) async {
    var shown = 0;

    final home = homePage ?? await client.fetch(DlwmsClient.homeUrl);
    shown += await _checkAnnouncements(home, client, prefs);
    shown += await _checkDocuments(home, prefs);

    await prefs.reload();
    final last = prefs.getInt(_lastExtendedKey) ?? 0;
    final due = forceExtended ||
        DateTime.now().millisecondsSinceEpoch - last >=
            extendedInterval.inMilliseconds;
    if (!due) return shown;

    // Each page is checked on its own so one failure doesn't hide the rest.
    for (final check in [_checkGrades, _checkTests, _checkExamTerms]) {
      try {
        shown += await check(client, prefs);
      } on DlwmsAuthException {
        rethrow;
      } catch (e) {
        debugPrint('[DlwmsWatchers] check failed: $e');
      }
    }
    await prefs.setInt(
        _lastExtendedKey, DateTime.now().millisecondsSinceEpoch);
    return shown;
  }

  static Future<int> _checkAnnouncements(
    DlwmsPage home,
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final current = NotificationService.parseNotifications(home);
    final fresh = await ObavijestiWatcher.detectNew(current, prefs);
    if (!AlertKind.obavijesti.isEnabled(prefs)) return 0;
    final alerted = await ObavijestiWatcher.alert(fresh, client, prefs);
    return alerted.length;
  }

  static Future<int> _checkDocuments(
    DlwmsPage home,
    SharedPreferences prefs,
  ) async {
    final current = IspitiService.parseSidebarDocuments(home);
    final fresh =
        await SeenStore.detectNew(prefs, _documentsKey, current, (d) => d.id);
    if (!AlertKind.dokumenti.isEnabled(prefs)) return 0;

    for (final document in fresh.take(_maxPerKind)) {
      await LocalNotifications.show(
        channel: NotifyChannel.dokumenti,
        key: document.id,
        title: document.subject.isEmpty
            ? 'Novi dokument'
            : 'Novi dokument · ${document.subject}',
        body: document.title,
        target: const NotificationTarget.tab(AppTab.dokumenti),
      );
    }
    return fresh.take(_maxPerKind).length;
  }

  static Future<int> _checkGrades(
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final page = await client.fetch(DlwmsClient.uspjehUrl);
    final data = UspjehService.parseUspjehPage(page);
    final current = [for (final group in data.passed) ...group.exams];
    final fresh = await SeenStore.detectNew(prefs, _gradesKey, current, gradeId);
    if (!AlertKind.ocjene.isEnabled(prefs)) return 0;

    for (final exam in fresh.take(_maxPerKind)) {
      final details = [
        if (exam.grade != null) 'Ocjena ${exam.grade}',
        if (exam.gradeDescription.isNotEmpty) '(${exam.gradeDescription})',
        if (exam.date != null) '· ${DateFormat('dd.MM.yyyy').format(exam.date!)}',
      ].join(' ');
      await LocalNotifications.show(
        channel: NotifyChannel.ocjene,
        key: gradeId(exam),
        title: 'Nova ocjena: ${exam.subject}',
        body: details.isEmpty ? 'Upisana je nova ocjena.' : details,
        target: const NotificationTarget.tab(AppTab.uspjeh),
      );
    }
    return fresh.take(_maxPerKind).length;
  }

  static String gradeId(PassedExam exam) =>
      '${exam.subject}|${exam.grade}|${exam.date?.toIso8601String() ?? ''}';

  static Future<int> _checkTests(
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final page = await client.fetch(DlwmsClient.testsUrl);
    final data = IspitiService.parseTests(page);

    final newResults = await SeenStore.detectNew(
        prefs, _testResultsKey, data.results, (t) => t.id);
    // Active tests: an empty list is normal, so remember "nothing" as well.
    final newActive = data.active.isEmpty
        ? const <ActiveTest>[]
        : await SeenStore.detectNew(
            prefs, _activeTestsKey, data.active, (t) => t.id);
    if (prefs.getStringList(_activeTestsKey) == null) {
      await prefs.setStringList(_activeTestsKey, const []);
    }
    if (!AlertKind.testovi.isEnabled(prefs)) return 0;

    var shown = 0;
    for (final test in newActive.take(_maxPerKind)) {
      final until =
          test.to == null ? '' : ' · do ${DateFormat('HH:mm').format(test.to!)}';
      final duration =
          test.durationMinutes == null ? '' : ' · ${test.durationMinutes} min';
      await LocalNotifications.show(
        channel: NotifyChannel.testovi,
        key: 'active|${test.id}',
        title: 'Aktivan test: ${test.subject}',
        body: '${test.name}$until$duration',
        target: const NotificationTarget.tab(AppTab.ispiti),
      );
      shown++;
    }
    for (final result in newResults.take(_maxPerKind)) {
      final score = result.percentage == null
          ? ''
          : ': ${formatPercent(result.percentage!)}';
      await LocalNotifications.show(
        channel: NotifyChannel.testovi,
        key: 'result|${result.id}',
        title: 'Rezultat testa: ${result.subject}',
        body: '${result.name}$score',
        target: const NotificationTarget.tab(AppTab.ispiti),
      );
      shown++;
    }
    return shown;
  }

  static Future<int> _checkExamTerms(
    DlwmsClient client,
    SharedPreferences prefs,
  ) async {
    final page = await client.fetch(DlwmsClient.examTermsUrl);
    final data = IspitiService.parseTerms(page);

    final newPeriods = await SeenStore.detectNew(
        prefs, _periodsKey, data.periods.where((p) => p.value.isNotEmpty).toList(),
        (p) => p.value);
    final newTerms =
        await SeenStore.detectNew(prefs, _termsKey, data.terms, (t) => t.id);
    if (!AlertKind.rokovi.isEnabled(prefs)) return 0;

    // Apsolventski periods are hidden in the app unless turned on; don't
    // alert about them either.
    final showAbsolvent =
        prefs.getBool(IspitiProvider.showAbsolventKey) ?? false;
    final hiddenIds = {
      for (final p in data.periods)
        if (!showAbsolvent && IspitiProvider.isAbsolvent(p)) p.value,
    };

    var shown = 0;
    final newPeriodIds = newPeriods.map((p) => p.value).toSet();
    for (final period in newPeriods
        .where((p) => !hiddenIds.contains(p.value))
        .take(_maxPerKind)) {
      await LocalNotifications.show(
        channel: NotifyChannel.rokovi,
        key: 'period|${period.value}',
        title: 'Objavljen novi ispitni rok',
        body: period.label,
        target: const NotificationTarget.tab(AppTab.ispiti),
      );
      shown++;
    }
    // Terms of a brand-new period are covered by the period alert.
    final terms = newTerms
        .where((t) =>
            !newPeriodIds.contains(t.periodId) &&
            !hiddenIds.contains(t.periodId))
        .toList();
    for (final term in terms.take(_maxPerKind)) {
      await LocalNotifications.show(
        channel: NotifyChannel.rokovi,
        key: 'term|${term.id}',
        title: 'Novi termin ispita: ${term.subject}',
        body: '${term.dateText} u ${term.timeText}',
        target: const NotificationTarget.tab(AppTab.ispiti),
      );
      shown++;
    }
    return shown;
  }

  /// "62,16 %" in Bosnian number format (no locale data needed).
  static String formatPercent(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return '${text.replaceAll('.', ',')} %';
  }

  /// Forgets everything seen, e.g. when another student logs in.
  static Future<void> reset(SharedPreferences prefs) async {
    await ObavijestiWatcher.reset(prefs);
    for (final key in [
      _documentsKey,
      _gradesKey,
      _testResultsKey,
      _activeTestsKey,
      _periodsKey,
      _termsKey,
      _lastExtendedKey,
    ]) {
      await prefs.remove(key);
    }
  }
}
