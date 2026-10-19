import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/watchers.dart';
import 'package:dlwms_mobile/util/credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Choices for "Učestalost provjere", in minutes.
const List<int> checkIntervalChoices = [5, 15, 30, 60];
const int defaultCheckIntervalMinutes = 15;
const String checkIntervalKey = 'check_interval_minutes';

/// How often DLWMS is checked, both in the background (Android may stretch
/// this while the phone is idle) and while the app is open.
Duration checkInterval(SharedPreferences prefs) {
  final minutes = prefs.getInt(checkIntervalKey);
  return Duration(
    minutes: checkIntervalChoices.contains(minutes)
        ? minutes!
        : defaultCheckIntervalMinutes,
  );
}

/// Message sent from the background check to the UI after every check.
const String checkDoneMessage = 'check_done';

const int _alarmId = 300;
const String _uiPortName = 'dlwms_ui_port';
const String _scheduledKey = 'background_alarm_scheduled';

/// Channels used by the old foreground service (removed in 0.4).
const List<String> _oldChannels = [
  'dlwms_background_silent',
  'dlwms_background_check',
];

/// Session kept between runs while Android keeps the background isolate
/// alive, so DLWMS isn't logged into every five minutes.
DlwmsClient? _backgroundClient;

/// Runs one background check. Started by a periodic, inexact alarm, so no
/// notification has to be shown while it runs (unlike a foreground service).
@pragma('vm:entry-point')
Future<void> backgroundCheckCallback() async {
  DartPluginRegistrant.ensureInitialized();

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    await LocalNotifications.init();

    final credentials = await CredentialStore.read(prefs);
    if (credentials == null) {
      await CheckStatus.save(prefs, CheckResult.authFailed);
      return;
    }

    final client = _backgroundClient ??= DlwmsClient();
    client.setCredentials(credentials.username, credentials.password);

    final shown = await DlwmsWatchers.runChecks(client, prefs);
    await CheckStatus.save(prefs, CheckResult.ok, newCount: shown);
  } on DlwmsAuthException {
    if (prefs != null) await CheckStatus.save(prefs, CheckResult.authFailed);
  } catch (e) {
    debugPrint('[backgroundCheck] failed: $e');
    if (prefs != null) await CheckStatus.save(prefs, CheckResult.error);
  } finally {
    // Lets an open app refresh the list and the "last check" line.
    IsolateNameServer.lookupPortByName(_uiPortName)
        ?.send({'type': checkDoneMessage});
  }
}

/// UI-side control of the background check (Android only).
class BackgroundService {
  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  static const MethodChannel _system = MethodChannel('dev.voloder.dlwms/system');

  static ReceivePort? _port;
  static final List<void Function(Object data)> _listeners = [];

  /// Call once in `main()` before `runApp`.
  static Future<void> initialize() async {
    if (!isSupported) return;

    final port = ReceivePort();
    IsolateNameServer.removePortNameMapping(_uiPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, _uiPortName);
    port.listen((message) {
      if (message == null) return;
      for (final listener in List.of(_listeners)) {
        listener(message as Object);
      }
    });
    _port = port;

    try {
      await AndroidAlarmManager.initialize();
    } catch (e) {
      debugPrint('[BackgroundService] init failed: $e');
    }
  }

  /// Whether the periodic background check is scheduled.
  static Future<bool> get isRunning async {
    if (!isSupported) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_scheduledKey) ?? false;
  }

  /// Schedules the periodic check (and asks for the permissions it needs).
  /// Returns whether it is scheduled afterwards.
  static Future<bool> start(SharedPreferences prefs) async {
    if (!isSupported) return false;

    try {
      await LocalNotifications.requestPermission();

      // Without this, Android delays background work a lot while the phone
      // is idle. Ask only once.
      if (!(prefs.getBool(PrefKeys.batteryPromptShown) ?? false)) {
        await prefs.setBool(PrefKeys.batteryPromptShown, true);
        try {
          await _system.invokeMethod('requestIgnoreBatteryOptimizations');
        } catch (_) {}
      }

      for (final channel in _oldChannels) {
        await LocalNotifications.deleteChannel(channel);
      }

      final ok = await AndroidAlarmManager.periodic(
        checkInterval(prefs),
        _alarmId,
        backgroundCheckCallback,
        startAt: DateTime.now().add(const Duration(minutes: 1)),
        allowWhileIdle: true,
        wakeup: true,
        rescheduleOnReboot: true,
      );
      await prefs.setBool(_scheduledKey, ok);
      return ok;
    } catch (e) {
      debugPrint('[BackgroundService] start failed: $e');
      await prefs.setBool(_scheduledKey, false);
      return false;
    }
  }

  static Future<void> stop() async {
    if (!isSupported) return;
    try {
      await AndroidAlarmManager.cancel(_alarmId);
    } catch (e) {
      debugPrint('[BackgroundService] stop failed: $e');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_scheduledKey, false);
  }

  static void addListener(void Function(Object data) callback) {
    if (isSupported) _listeners.add(callback);
  }

  static void removeListener(void Function(Object data) callback) {
    _listeners.remove(callback);
  }

  /// Keeps the analyzer happy about the port being retained on purpose.
  @visibleForTesting
  static bool get hasPort => _port != null;
}
