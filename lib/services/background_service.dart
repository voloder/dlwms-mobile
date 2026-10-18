import 'dart:io';

import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
import 'package:dlwms_mobile/util/credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How often DLWMS is checked for new announcements.
const Duration obavijestiCheckInterval = Duration(seconds: 300);

/// Message sent from the service to the UI after every check.
const String checkDoneMessage = 'check_done';

/// Channel used by the foreground service. It is created with importance
/// NONE, so Android shows nothing for it in the status bar or the shade.
/// (Channel settings can't change once created, hence a new id.)
const String _serviceChannelId = 'dlwms_background_silent';
const String _oldServiceChannelId = 'dlwms_background_check';
const String _channelPrefKey = 'background_service_channel';

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

  /// Runs one check and records the outcome for the settings sheet. The
  /// service's own notification is invisible, so nothing is updated there.
  Future<void> _check() async {
    if (_checking) return;
    _checking = true;

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final credentials = Credentials.read(prefs);
      if (credentials == null) {
        await CheckStatus.save(prefs, CheckResult.authFailed);
        return;
      }

      final client = _client ??= DlwmsClient();
      client.setCredentials(credentials.username, credentials.password);

      final alerted = await ObavijestiWatcher.checkForNew(client, prefs);
      await CheckStatus.save(prefs, CheckResult.ok, newCount: alerted.length);
    } on DlwmsAuthException {
      if (prefs != null) await CheckStatus.save(prefs, CheckResult.authFailed);
    } catch (e) {
      debugPrint('[ObavijestiTaskHandler] check failed: $e');
      if (prefs != null) await CheckStatus.save(prefs, CheckResult.error);
    } finally {
      _checking = false;
      // Lets an open app refresh the list and the "last check" line.
      FlutterForegroundTask.sendDataToMain({'type': checkDoneMessage});
    }
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
        channelId: _serviceChannelId,
        channelName: 'Provjera obavijesti u pozadini',
        channelDescription:
            'Tehnički kanal pozadinske provjere. Ne prikazuje obavještenja; '
            'status provjere je u postavkama aplikacije.',
        channelImportance: NotificationChannelImportance.NONE,
        priority: NotificationPriority.MIN,
        visibility: NotificationVisibility.VISIBILITY_SECRET,
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

      // A service started by an older version still uses the old, visible
      // channel; restart it from scratch so it picks up the silent one.
      final migrated = prefs.getString(_channelPrefKey) == _serviceChannelId;
      if (await FlutterForegroundTask.isRunningService) {
        if (migrated) {
          await FlutterForegroundTask.restartService();
          return true;
        }
        await FlutterForegroundTask.stopService();
      }

      final result = await FlutterForegroundTask.startService(
        serviceId: 300,
        serviceTypes: [ForegroundServiceTypes.specialUse],
        notificationTitle: 'DLWMS',
        notificationText: 'Provjera obavijesti',
        notificationInitialRoute: '/',
        callback: obavijestiServiceCallback,
      );

      if (result is ServiceRequestSuccess) {
        await prefs.setString(_channelPrefKey, _serviceChannelId);
        await LocalNotifications.deleteChannel(_oldServiceChannelId);
        return true;
      }
      return false;
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
