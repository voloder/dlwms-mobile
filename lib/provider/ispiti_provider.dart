import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/calendar_service.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/exam_reminders.dart';
import 'package:dlwms_mobile/services/ispiti_service.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/widgets.dart';

enum IspitiProviderState { loading, loaded, error }

/// Exam terms (`rokovi/index.aspx`) plus currently active tests.
class IspitiProvider extends ChangeNotifier {
  AuthProvider? _authProvider;

  IspitiProviderState _state = IspitiProviderState.loading;
  String? _errorMessage;
  DlwmsPage? _page;
  ExamTermsPageData? _data;
  List<ActiveTest> _activeTests = const [];
  bool _busy = false;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  IspitiProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _busy;

  List<DlwmsFilterOption> get periods =>
      (_data?.periods ?? const []).where((p) => p.value.isNotEmpty).toList();
  String get selectedPeriod => selectedOption(periods)?.value ?? '';
  String get selectedPeriodName => selectedOption(periods)?.label ?? '';

  List<ExamTerm> get terms => _data?.terms ?? const [];
  List<ExamTerm> get upcoming => terms.where((t) => !t.isPast()).toList();
  List<ExamTerm> get past => terms.where((t) => t.isPast()).toList();
  List<ActiveTest> get activeTests => _activeTests;

  DlwmsClient get _client {
    final auth = _authProvider;
    if (auth == null) {
      throw StateError('Auth provider is not wired to IspitiProvider.');
    }
    return auth.client;
  }

  Future<void> fetch() => _run(() async {
        final results = await Future.wait([
          _client.fetch(DlwmsClient.examTermsUrl),
          _loadActiveTests(),
        ]);
        _apply(results[0] as DlwmsPage);
      });

  Future<void> refresh() => fetch();

  Future<void> setPeriod(String value) async {
    final page = _page;
    if (page == null || value == selectedPeriod) return;
    await _run(() async {
      _apply(await _client.postBack(page, IspitiService.periodField,
          fields: {IspitiService.periodField: value}));
    });
  }

  /// Active tests are a bonus: a failure here shouldn't hide the terms.
  Future<DlwmsPage?> _loadActiveTests() async {
    try {
      final page = await _client.fetch(DlwmsClient.testsUrl);
      _activeTests = IspitiService.parseTests(page).active;
      return page;
    } catch (_) {
      _activeTests = const [];
      return null;
    }
  }

  bool hasReminder(ExamTerm term) {
    final prefs = _authProvider?.prefs;
    return prefs != null && ExamReminders.isSet(prefs, term);
  }

  /// Turns the reminder on or off. Returns the result when turning it on.
  Future<ReminderResult?> toggleReminder(ExamTerm term) async {
    final prefs = _authProvider?.prefs;
    if (prefs == null) return ReminderResult.failed;

    ReminderResult? result;
    if (ExamReminders.isSet(prefs, term)) {
      await ExamReminders.disable(prefs, term);
    } else {
      result = await ExamReminders.enable(prefs, term);
    }
    notifyListeners();
    return result;
  }

  Future<bool> addToCalendar(ExamTerm term) =>
      CalendarService.addExam(term, periodName: selectedPeriodName);

  void _apply(DlwmsPage page) {
    _page = page;
    _data = IspitiService.parseTerms(page);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    if (_data == null) _state = IspitiProviderState.loading;
    notifyListeners();

    try {
      await action();
      _state = IspitiProviderState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      if (_data == null) _state = IspitiProviderState.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
