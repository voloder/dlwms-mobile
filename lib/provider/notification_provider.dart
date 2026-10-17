import 'dart:async';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
import 'package:flutter/widgets.dart';

enum NotificationProviderState { loading, loaded, error }

/// Home-page announcements. Refreshes every 300 s while the app is open, and
/// immediately when the background service reports new items.
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
      _startTimer();
    } else {
      _stopTimer();
      _notifications = null;
      _state = NotificationProviderState.loading;
    }
  }

  List<DlwmsNotification>? _notifications;
  NotificationProviderState _state = NotificationProviderState.loading;
  String? _errorMessage;

  List<DlwmsNotification>? get notifications => _notifications;
  NotificationProviderState get state => _state;
  String? get errorMessage => _errorMessage;

  set state(NotificationProviderState state) {
    _state = state;
    notifyListeners();
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
      final page = await auth.client.fetch(DlwmsClient.homeUrl);
      final list = NotificationService.parseNotifications(page);

      _notifications = list;
      _errorMessage = null;
      state = NotificationProviderState.loaded;

      await _handleNewItems(auth, list);
    } catch (e) {
      _errorMessage = e.toString();
      if (!silent || _notifications == null) {
        state = NotificationProviderState.error;
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _handleNewItems(
      AuthProvider auth, List<DlwmsNotification> list) async {
    // The background service owns alerting while it runs, so it doesn't
    // lose track of what's new.
    if (await BackgroundService.isRunning) return;

    final fresh = await ObavijestiWatcher.detectNew(list, auth.prefs);
    for (final notification in fresh.take(5)) {
      await LocalNotifications.showNewNotification(notification);
    }
  }

  Future<DlwmsNotificationDetail> fetchDetail(DlwmsNotification n) async {
    final auth = _authProvider;
    final url = n.url;
    if (auth == null || url == null) {
      throw DlwmsNetworkException('Obavijest nema detaljan prikaz.');
    }
    final page = await auth.client.fetch(Uri.parse(url));
    return NotificationService.parseDetail(page);
  }

  void _onServiceData(Object data) {
    if (data is Map && data['type'] == newObavijestiMessage) {
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
