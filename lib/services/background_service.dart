import 'dart:io';

import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
import 'package:dlwms_mobile/util/credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How often DLWMS is checked for new announcements.
const Duration obavijestiCheckInterval = Duration(seconds: 300);

/// Message type sent from the service to the UI when new items were found.
const String newObavijestiMessage = 'new_obavijesti';

/// Entry point of the background isolate. Must be top-level.
@pragma('vm:entry-point')
void obavijestiServiceCallback() {
  FlutterForegroundTask.setTaskHandler(ObavijestiTaskHandler());
}

/// Runs inside the Android foreground service: every 300 s it logs in (only
/// when the session has expired), reads the home page and shows a local
/// notification for every announcement that wasn't there before.
class ObavijestiTaskHandler extends TaskHandler {
  DlwmsClient? _client;
  bool _checking = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await LocalNotifications.init();
    await _check();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _check();
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _client?.close();
    _client = null;
  }

  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    final time = DateFormat('HH:mm').format(DateTime.now());

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final credentials = Credentials.read(prefs);
      if (credentials == null) {
        await _updateText('Niste prijavljeni – otvorite aplikaciju.');
        return;
      }

      final client = _client ??= DlwmsClient();
      client.setCredentials(credentials.username, credentials.password);

      final fresh = await ObavijestiWatcher.checkForNew(client, prefs);

      await _updateText(fresh.isEmpty
          ? 'Zadnja provjera u $time · nema novih obavijesti'
          : 'Zadnja provjera u $time · ${fresh.length} nova/e obavijest/i');

      if (fresh.isNotEmpty) {
        FlutterForegroundTask.sendDataToMain({
          'type': newObavijestiMessage,
          'count': fresh.length,
        });
      }
    } on DlwmsAuthException {
      await _updateText('Prijava nije uspjela – otvorite aplikaciju.');
    } catch (e) {
      debugPrint('[ObavijestiTaskHandler] check failed: $e');
      await _updateText('Provjera u $time nije uspjela, pokušavam ponovo.');
    } finally {
      _checking = false;
    }
  }

  Future<void> _updateText(String text) async {
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'DLWMS · provjera obavijesti',
        notificationText: text,
      );
    } catch (_) {}
  }
}

/// UI-side control of the background check (Android only).
class BackgroundService {
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static bool _configured = false;

  /// Call once in `main()` before `runApp`.
  static void initCommunicationPort() {
    if (isSupported) FlutterForegroundTask.initCommunicationPort();
  }

  static void _configure() {
    if (_configured) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'dlwms_background_check',
        channelName: 'Provjera obavijesti u pozadini',
        channelDescription:
            'Prikazuje se dok aplikacija svakih 5 minuta provjerava nove obavijesti.',
        channelImportance: NotificationChannelImportance.MIN,
        priority: NotificationPriority.MIN,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          obavijestiCheckInterval.inMilliseconds,
        ),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
    _configured = true;
  }

  static Future<bool> get isRunning async {
    if (!isSupported) return false;
    try {
      return await FlutterForegroundTask.isRunningService;
    } catch (_) {
      return false;
    }
  }

  /// Requests the needed permissions and starts the service. Returns whether
  /// the service is running afterwards.
  static Future<bool> start(SharedPreferences prefs) async {
    if (!isSupported) return false;

    try {
      final permission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }

      // Without this, Doze may delay checks for a long time. Ask only once.
      if (!(prefs.getBool(PrefKeys.batteryPromptShown) ?? false) &&
          !await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await prefs.setBool(PrefKeys.batteryPromptShown, true);
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }

      _configure();

      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
        return true;
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 300,
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: 'DLWMS · provjera obavijesti',
        notificationText: 'Nove obavijesti se provjeravaju svakih 5 minuta.',
        notificationInitialRoute: '/',
        callback: obavijestiServiceCallback,
      );
      return result is ServiceRequestSuccess;
    } catch (e) {
      debugPrint('[BackgroundService] start failed: $e');
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('[BackgroundService] stop failed: $e');
    }
  }

  static void addListener(void Function(Object data) callback) {
    if (isSupported) FlutterForegroundTask.addTaskDataCallback(callback);
  }

  static void removeListener(void Function(Object data) callback) {
    if (isSupported) FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}
