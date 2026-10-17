import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/models/prisustvo.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/prisustvo_service.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/widgets.dart';

enum PrisustvoProviderState { loading, loaded, error }

/// Attendance per subject (`nastava/prisustvo.aspx`).
class PrisustvoProvider extends ChangeNotifier {
  static const _yearField = r'ctl00$ContentPlaceHolder1$listGodine';

  AuthProvider? _authProvider;

  PrisustvoProviderState _state = PrisustvoProviderState.loading;
  String? _errorMessage;
  DlwmsPage? _page;
  PrisustvoPageData? _data;
  bool _busy = false;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  PrisustvoProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _busy;

  List<DlwmsFilterOption> get yearOptions => _data?.yearOptions ?? const [];
  List<PrisustvoSubject> get subjects => _data?.subjects ?? const [];
  String get selectedYear => selectedOption(yearOptions)?.value ?? '';

  DlwmsClient get _client {
    final auth = _authProvider;
    if (auth == null) {
      throw StateError('Auth provider is not wired to PrisustvoProvider.');
    }
    return auth.client;
  }

  Future<void> fetch() => _run(() async {
        _apply(await _client.fetch(DlwmsClient.prisustvoUrl));
      });

  Future<void> refresh() => fetch();

  Future<void> setYear(String value) async {
    final page = _page;
    if (page == null || value == selectedYear) return;
    await _run(() async {
      _apply(await _client
          .postBack(page, _yearField, fields: {_yearField: value}));
    });
  }

  /// Loads the lectures/exercises breakdown for [subject].
  Future<PrisustvoDetail> fetchDetail(PrisustvoSubject subject) async {
    final page = _page;
    final target = subject.postBackTarget;
    if (page == null || target == null) {
      throw DlwmsNetworkException('Detalji nisu dostupni.');
    }

    final result = await _client.postBack(page, target);
    final detail = PrisustvoService.parsePrisustvoPage(result).detail;
    if (detail == null) {
      throw DlwmsNetworkException('Detalji nisu dostupni.');
    }
    return detail;
  }

  void _apply(DlwmsPage page) {
    _page = page;
    _data = PrisustvoService.parsePrisustvoPage(page);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    if (_data == null) _state = PrisustvoProviderState.loading;
    notifyListeners();

    try {
      await action();
      _state = PrisustvoProviderState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      if (_data == null) _state = PrisustvoProviderState.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
