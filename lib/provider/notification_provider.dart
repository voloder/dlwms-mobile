import 'dart:async';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/relevant_subjects.dart';
import 'package:dlwms_mobile/services/watchers.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/widgets.dart';

enum NotificationProviderState { loading, loaded, error }

/// Home-page announcements. Refreshes every 300 s while the app is open, and
/// when the background service reports a check with new items.
///
/// Also owns the "Prikaži samo relevantne obavijesti" setting and the status
/// of the last check, both shown in the settings sheet.
///
/// On Android the background service is responsible for alerts; when it isn't
/// running (iOS, or the user turned it off) this provider raises them itself
/// while the app is open.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider() {
    _lifecycle = AppLifecycleListener(
      onResume: () {
        if (_isAuthenticated) {
          fetchNotifications(silent: true);
          _startTimer();
        }
      },
      onPause: _stopTimer,
    );
    BackgroundService.addListener(_onServiceData);
  }

  AuthProvider? _authProvider;
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  bool get _isAuthenticated =>
      _authProvider?.state == AuthProviderState.authenticated;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
    if (_isAuthenticated) {
      _relevantSubjects ??= RelevantSubjects.cached(authProvider.prefs);
      _startTimer();
    } else {
      _stopTimer();
      _notifications = null;
      _pagerPage = null;
      _nextPage = null;
      _relevantSubjects = null;
      _state = NotificationProviderState.loading;
    }
  }

  List<DlwmsNotification>? _notifications;
  List<String>? _relevantSubjects;
  bool _loadingSubjects = false;
  NotificationProviderState _state = NotificationProviderState.loading;
  String? _errorMessage;

  NotificationProviderState get state => _state;
  String? get errorMessage => _errorMessage;

  /// Everything on the DLWMS home page.
  List<DlwmsNotification>? get allNotifications => _notifications;

  /// What the Početna tab shows: all announcements, or only relevant ones.
  List<DlwmsNotification>? get notifications {
    final all = _notifications;
    if (all == null || !relevantOnly) return all;
    return RelevantSubjects.filter(all, _relevantSubjects);
  }

  /// How many announcements the filter currently hides.
  int get hiddenCount =>
      (_notifications?.length ?? 0) - (notifications?.length ?? 0);

  bool get relevantOnly {
    final prefs = _authProvider?.prefs;
    return prefs != null && RelevantSubjects.isEnabled(prefs);
  }

  /// Subjects that count as relevant (null until loaded once).
  List<String>? get relevantSubjects => _relevantSubjects;
  bool get loadingRelevantSubjects => _loadingSubjects;

  CheckStatus? get lastCheck {
    final prefs = _authProvider?.prefs;
    return prefs == null ? null : CheckStatus.read(prefs);
  }

  set state(NotificationProviderState state) {
    _state = state;
    notifyListeners();
  }

  Future<void> setRelevantOnly(bool enabled) async {
    final auth = _authProvider;
    if (auth == null) return;
    await RelevantSubjects.setEnabled(auth.prefs, enabled);
    notifyListeners();
    if (enabled) await refreshRelevantSubjects();
  }

  /// Loads the relevant subject list (from cache unless stale or [force]).
  Future<void> refreshRelevantSubjects({bool force = false}) async {
    final auth = _authProvider;
    if (auth == null || _loadingSubjects) return;

    _loadingSubjects = true;
    notifyListeners();
    try {
      _relevantSubjects =
          await RelevantSubjects.load(auth.client, auth.prefs, force: force);
    } finally {
      _loadingSubjects = false;
      notifyListeners();
    }
  }

  bool _fetching = false;

  /// Loads the announcements. With [silent], the current list stays visible
  /// while refreshing and errors don't replace it.
  Future<void> fetchNotifications({bool silent = false}) async {
    final auth = _authProvider;
    if (auth == null || _fetching) return;
    _fetching = true;

    if (!silent || _notifications == null) {
      state = NotificationProviderState.loading;
    }

    try {
      if (relevantOnly) {
        _relevantSubjects =
            await RelevantSubjects.load(auth.client, auth.prefs);
      }

      final page = await auth.client.fetch(DlwmsClient.homeUrl);
      final list = NotificationService.parseNotifications(page);

      _notifications = list;
      _pagerPage = page;
      _nextPage = nextPageTarget(NotificationService.parseHomePager(page));
      _errorMessage = null;
      state = NotificationProviderState.loaded;

      await _handleNewItems(auth, page);
    } catch (e) {
      _errorMessage = e.toString();
      if (!await BackgroundService.isRunning) {
        await CheckStatus.save(auth.prefs, CheckResult.error);
      }
      if (!silent || _notifications == null) {
        state = NotificationProviderState.error;
      } else {
        notifyListeners();
      }
    } finally {
      _fetching = false;
    }
  }

  /// Runs the same checks as the background service (announcements,
  /// documents, grades, tests, exam terms) while the app is open, but only
  /// when that service isn't running – it owns alerting otherwise.
  Future<void> _handleNewItems(AuthProvider auth, DlwmsPage homePage) async {
    if (await BackgroundService.isRunning) return;

    try {
      final shown = await DlwmsWatchers.runChecks(
        auth.client,
        auth.prefs,
        homePage: homePage,
      );
      await CheckStatus.save(auth.prefs, CheckResult.ok, newCount: shown);
    } catch (_) {
      await CheckStatus.save(auth.prefs, CheckResult.error);
    }
    notifyListeners();
  }

  // Paging through older announcements ("Učitaj starije").
  DlwmsPage? _pagerPage;
  String? _nextPage;
  bool _loadingMore = false;
  String? _loadMoreError;

  bool get hasMore => _nextPage != null;
  bool get loadingMore => _loadingMore;
  String? get loadMoreError => _loadMoreError;

  /// Appends the next page of DLWMS announcements (10 per page).
  Future<void> loadMore() async {
    final auth = _authProvider;
    final page = _pagerPage;
    final target = _nextPage;
    if (auth == null || page == null || target == null || _loadingMore) {
      return;
    }

    _loadingMore = true;
    _loadMoreError = null;
    notifyListeners();
    try {
      final next = await auth.client.postBack(page, target);
      final more = NotificationService.parseNotifications(next);
      final known = {for (final n in _notifications ?? const []) n.id};
      _notifications = [
        ...?_notifications,
        ...more.where((n) => !known.contains(n.id)),
      ];
      _pagerPage = next;
      _nextPage = more.isEmpty
          ? null
          : nextPageTarget(NotificationService.parseHomePager(next));
    } catch (e) {
      _loadMoreError = e.toString();
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  Future<DlwmsNotificationDetail> fetchDetail(String url) async {
    final auth = _authProvider;
    if (auth == null) {
      throw DlwmsNetworkException('Obavijest nema detaljan prikaz.');
    }
    final page = await auth.client.fetch(Uri.parse(url));
    return NotificationService.parseDetail(page);
  }

  Future<void> _onServiceData(Object data) async {
    if (data is! Map || data['type'] != checkDoneMessage) return;

    final prefs = _authProvider?.prefs;
    if (prefs == null) return;
    await prefs.reload();
    _relevantSubjects = RelevantSubjects.cached(prefs) ?? _relevantSubjects;
    notifyListeners();

    if ((CheckStatus.read(prefs)?.newCount ?? 0) > 0) {
      fetchNotifications(silent: true);
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(obavijestiCheckInterval, (_) {
      fetchNotifications(silent: true);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopTimer();
    _lifecycle.dispose();
    BackgroundService.removeListener(_onServiceData);
    super.dispose();
  }
}
