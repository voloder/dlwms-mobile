import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:flutter/widgets.dart';

import '../services/notification_service.dart';

enum NotificationProviderState { loading, loaded, error }

class NotificationProvider extends ChangeNotifier {
  AuthProvider? _authProvider;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  final notificationsUrl =
  Uri.parse("https://www.fit.ba/student/default.aspx");

  List<DlwmsNotification>? _notifications;

  NotificationProviderState _state = NotificationProviderState.loading;

  List<DlwmsNotification>? get notifications => _notifications;
  NotificationProviderState get state => _state;

  set state(NotificationProviderState state) {
    _state = state;
    notifyListeners();
  }


  Future<void> fetchNotifications() async {
    state = NotificationProviderState.loading;
    assert (_authProvider != null);

    final response = await _authProvider!.fetchWithAuth(notificationsUrl);

    debugPrint("Notification fetch response status: ${response.statusCode}");
    debugPrint("Notification fetch response body: ${response.body}");

    _notifications = NotificationService.parseNotificationsFromHtml(response.body);

    state = NotificationProviderState.loaded;
  }
}