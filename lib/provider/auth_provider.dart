import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/check_status.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/exam_reminders.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/relevant_subjects.dart';
import 'package:dlwms_mobile/services/watchers.dart';
import 'package:dlwms_mobile/util/credentials.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthProviderState {
  authenticated,
  unauthenticated,
  authenticating,
  error,
  initial,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._prefs, {DlwmsClient? client})
      : client = client ?? DlwmsClient() {
    _restore();
  }

  /// Logs in with the saved credentials, if there are any.
  Future<void> _restore() async {
    Credentials? saved;
    try {
      saved = await CredentialStore.read(_prefs);
    } catch (_) {
      saved = null;
    }
    if (saved != null) {
      await login(saved.username, saved.password, isAuto: true);
    } else {
      state = AuthProviderState.unauthenticated;
    }
  }

  final SharedPreferences _prefs;

  /// Shared, authenticated DLWMS session used by all pages.
  final DlwmsClient client;

  SharedPreferences get prefs => _prefs;

  AuthProviderState _state = AuthProviderState.initial;
  AuthProviderState get state => _state;

  set state(AuthProviderState state) {
    _state = state;
    notifyListeners();
  }

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _backgroundRunning = false;
  bool get backgroundRunning => _backgroundRunning;

  String? get username => _prefs.getString(PrefKeys.username);

  bool get backgroundCheckEnabled =>
      _prefs.getBool(PrefKeys.backgroundCheck) ?? true;

  Future<void> login(String username, String password,
      {bool isAuto = false}) async {
    username = username.trim();
    if (username.isEmpty || password.isEmpty) {
      _errorMessage = 'Unesite broj indeksa i lozinku.';
      state = AuthProviderState.error;
      return;
    }

    _errorMessage = null;
    state =
        isAuto ? AuthProviderState.initial : AuthProviderState.authenticating;

    try {
      await client.login(username, password);

      final previousUser = _prefs.getString(PrefKeys.username);
      if (previousUser != null && previousUser != username) {
        await DlwmsWatchers.reset(_prefs);
        await RelevantSubjects.clear(_prefs);
        await ExamReminders.clear(_prefs);
      }
      await CredentialStore.save(_prefs, username, password);

      state = AuthProviderState.authenticated;
      _startBackgroundIfEnabled();
    } on DlwmsAuthException catch (e) {
      _errorMessage = e.message;
      state = AuthProviderState.error;
    } on DlwmsNetworkException catch (e) {
      _errorMessage = isAuto
          ? 'Nije moguće povezati se sa DLWMS-om. Provjerite internet konekciju.'
          : e.message;
      state = AuthProviderState.error;
    } catch (e) {
      _errorMessage = 'Neočekivana greška: $e';
      state = AuthProviderState.error;
    }
  }

  Future<void> _startBackgroundIfEnabled() async {
    await LocalNotifications.requestPermission();
    if (backgroundCheckEnabled) {
      _backgroundRunning = await BackgroundService.start(_prefs);
    } else {
      _backgroundRunning = await BackgroundService.isRunning;
    }
    notifyListeners();
  }

  int get checkIntervalMinutes => checkInterval(_prefs).inMinutes;

  /// Saves the check interval and reschedules the background check.
  Future<void> setCheckInterval(int minutes) async {
    if (minutes == checkIntervalMinutes) return;
    await _prefs.setInt(checkIntervalKey, minutes);
    notifyListeners();
    if (backgroundCheckEnabled) {
      _backgroundRunning = await BackgroundService.start(_prefs);
      notifyListeners();
    }
  }

  Future<void> setBackgroundCheckEnabled(bool enabled) async {
    await _prefs.setBool(PrefKeys.backgroundCheck, enabled);
    if (enabled) {
      _backgroundRunning = await BackgroundService.start(_prefs);
    } else {
      await BackgroundService.stop();
      _backgroundRunning = false;
    }
    notifyListeners();
  }

  Future<void> logout() async {
    await BackgroundService.stop();
    _backgroundRunning = false;
    await client.logout();
    await CredentialStore.clearPassword(_prefs);
    await DlwmsWatchers.reset(_prefs);
    await ExamReminders.clear(_prefs);
    await RelevantSubjects.clear(_prefs, includeEdits: false);
    await CheckStatus.clear(_prefs);
    _errorMessage = null;
    state = AuthProviderState.unauthenticated;
  }
}
