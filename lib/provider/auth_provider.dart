import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
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
    final saved = Credentials.read(_prefs);
    if (saved != null) {
      login(saved.username, saved.password, isAuto: true);
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
        await ObavijestiWatcher.reset(_prefs);
      }
      await _prefs.setString(PrefKeys.username, username);
      await _prefs.setString(PrefKeys.password, password);

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
    await _prefs.remove(PrefKeys.password);
    await ObavijestiWatcher.reset(_prefs);
    _errorMessage = null;
    state = AuthProviderState.unauthenticated;
  }
}
