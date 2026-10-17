import 'package:dlwms_mobile/models/uspjeh.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/uspjeh_service.dart';
import 'package:flutter/widgets.dart';

enum UspjehProviderState { loading, loaded, error }

/// Grades and study status (`evaluacija/uspjeh.aspx`).
class UspjehProvider extends ChangeNotifier {
  AuthProvider? _authProvider;

  UspjehProviderState _state = UspjehProviderState.loading;
  String? _errorMessage;
  UspjehPageData? _data;
  bool _busy = false;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  UspjehProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  UspjehPageData? get data => _data;

  Future<void> fetch() async {
    final auth = _authProvider;
    if (auth == null || _busy) return;
    _busy = true;
    _errorMessage = null;
    if (_data == null) {
      _state = UspjehProviderState.loading;
      notifyListeners();
    }

    try {
      final page = await auth.client.fetch(DlwmsClient.uspjehUrl);
      _data = UspjehService.parseUspjehPage(page);
      _state = UspjehProviderState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      if (_data == null) _state = UspjehProviderState.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => fetch();
}
