import 'dart:async';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Android notification channels, one per kind of alert, so each can also be
/// muted separately in the system settings.
enum NotifyChannel {
  obavijesti('dlwms_obavijesti', 'Nove obavijesti',
      'Kada se na DLWMS pojavi nova obavijest.'),
  ocjene('dlwms_ocjene', 'Nove ocjene', 'Kada se na Uspjehu pojavi nova ocjena.'),
  testovi('dlwms_testovi', 'Testovi',
      'Kada test postane aktivan ili stigne rezultat testa.'),
  rokovi('dlwms_rokovi', 'Ispitni rokovi',
      'Kada se objavi novi ispitni rok ili termin ispita.'),
  dokumenti('dlwms_dokumenti', 'Novi dokumenti',
      'Kada se objavi novi dokument iz tvojih predmeta.'),
  podsjetnici('dlwms_podsjetnici', 'Podsjetnici za ispite',
      'Podsjetnik dan prije ispita koji si označio/la.');

  const NotifyChannel(this.id, this.title, this.description);

  final String id;
  final String title;
  final String description;
}

/// Thin wrapper around flutter_local_notifications. Safe to use from both the
/// UI isolate and the background service isolate.
class LocalNotifications {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// DLWMS times are local to Bosnia and Herzegovina.
  static const String timeZone = 'Europe/Sarajevo';

  static final StreamController<NotificationTarget> _taps =
      StreamController<NotificationTarget>.broadcast();

  /// Notifications tapped while the app is running.
  static Stream<NotificationTarget> get taps => _taps.stream;

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
      tz_data.initializeTimeZones();
      await _plugin.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: (response) {
          final target = NotificationTarget.decode(response.payload);
          if (target != null) _taps.add(target);
        },
      );
      _initialized = true;
    } catch (e) {
      debugPrint('[LocalNotifications] init failed: $e');
    }
  }

  /// Target of the notification that started the app, if any.
  static Future<NotificationTarget?> launchTarget() async {
    await init();
    if (!_initialized) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details == null || !details.didNotificationLaunchApp) return null;
      return NotificationTarget.decode(details.notificationResponse?.payload);
    } catch (_) {
      return null;
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

  /// Removes a channel this app no longer uses (Android only).
  static Future<void> deleteChannel(String channelId) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.deleteNotificationChannel(channelId: channelId);
    } catch (e) {
      debugPrint('[LocalNotifications] deleteChannel failed: $e');
    }
  }

  static NotificationDetails _details(
    NotifyChannel channel, {
    required String title,
    required String body,
    String? subText,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.title,
        channelDescription: channel.description,
        importance: Importance.high,
        priority: Priority.high,
        subText: subText,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: subText,
        ),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
  }

  /// Stable 31-bit id (FNV-1a) so a scheduled reminder can be cancelled after
  /// the app restarts; `String.hashCode` isn't guaranteed to be stable.
  static int idFor(String key) {
    var hash = 0x811c9dc5;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash & 0x7fffffff;
  }

  static Future<void> show({
    required NotifyChannel channel,
    required String key,
    required String title,
    required String body,
    required NotificationTarget target,
    String? subText,
  }) async {
    await init();
    if (!_initialized) return;

    try {
      await _plugin.show(
        id: idFor('${channel.id}|$key'),
        title: title,
        body: body,
        notificationDetails:
            _details(channel, title: title, body: body, subText: subText),
        payload: target.encode(),
      );
    } catch (e) {
      debugPrint('[LocalNotifications] show failed: $e');
    }
  }

  static Future<void> showNewNotification(DlwmsNotification notification) {
    final subject =
        notification.subject.isEmpty ? null : notification.subject;
    final body = notification.content.isNotEmpty
        ? notification.content
        : [if (subject != null) subject, notification.author].join(' · ');
    final url = notification.url;

    return show(
      channel: NotifyChannel.obavijesti,
      key: notification.id,
      title: notification.title,
      body: body,
      subText: subject,
      target: url == null
          ? const NotificationTarget.tab(AppTab.pocetna)
          : NotificationTarget.announcement(url),
    );
  }

  /// Schedules a notification at [when] (Sarajevo time). Uses inexact
  /// alarms, so it may arrive a few minutes late but needs no extra
  /// permission. Returns false if [when] is already in the past.
  static Future<bool> schedule({
    required NotifyChannel channel,
    required String key,
    required DateTime when,
    required String title,
    required String body,
    required NotificationTarget target,
  }) async {
    await init();
    if (!_initialized) return false;

    final location = tz.getLocation(timeZone);
    final at = tz.TZDateTime(location, when.year, when.month, when.day,
        when.hour, when.minute);
    if (!at.isAfter(tz.TZDateTime.now(location))) return false;

    try {
      await _plugin.zonedSchedule(
        id: idFor('${channel.id}|$key'),
        title: title,
        body: body,
        scheduledDate: at,
        notificationDetails: _details(channel, title: title, body: body),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: target.encode(),
      );
      return true;
    } catch (e) {
      debugPrint('[LocalNotifications] schedule failed: $e');
      return false;
    }
  }

  static Future<void> cancel(NotifyChannel channel, String key) async {
    await init();
    if (!_initialized) return;
    try {
      await _plugin.cancel(id: idFor('${channel.id}|$key'));
    } catch (_) {}
  }
}
