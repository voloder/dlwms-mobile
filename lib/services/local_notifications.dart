import 'package:dlwms_mobile/models/notification.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications for "new Obavijest" alerts.
/// Safe to use from both the UI isolate and the background service isolate.
class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const String _channelId = 'dlwms_obavijesti';
  static const String _channelName = 'Nove obavijesti';
  static const String _channelDescription =
      'Obavještenje kada se na DLWMS pojavi nova obavijest.';

  static Future<void> init() async {
    if (_initialized || kIsWeb) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_stat_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    try {
      await _plugin.initialize(settings: settings);
      _initialized = true;
    } catch (e) {
      debugPrint('[LocalNotifications] init failed: $e');
    }
  }

  /// Asks for the notification permission (Android 13+, iOS).
  static Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  static Future<void> showNewNotification(DlwmsNotification notification) async {
    await init();
    if (!_initialized) return;

    final body = notification.content.isNotEmpty
        ? notification.content
        : '${notification.subject} · ${notification.author}';

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        subText: notification.subject,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: notification.title,
          summaryText: notification.subject,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        id: notification.id.hashCode & 0x7fffffff,
        title: notification.title,
        body: body,
        notificationDetails: details,
        payload: notification.url,
      );
    } catch (e) {
      debugPrint('[LocalNotifications] show failed: $e');
    }
  }
}
