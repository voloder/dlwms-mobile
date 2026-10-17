import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/models/nastava.dart';
import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/nastava_service.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/widgets.dart';

enum NastavaProviderState { loading, loaded, error }

/// Per-subject announcements and materials (`nastava/index.aspx`).
class NastavaProvider extends ChangeNotifier {
  static const _yearField = r'ctl00$ContentPlaceHolder1$listGodina';
  static const _subjectField = r'ctl00$ContentPlaceHolder1$ddlPredmeti';

  AuthProvider? _authProvider;

  NastavaProviderState _state = NastavaProviderState.loading;
  String? _errorMessage;
  DlwmsPage? _page;
  NastavaPageData? _data;
  bool _busy = false;
  String? _downloadingTarget;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  NastavaProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _busy;
  String? get downloadingTarget => _downloadingTarget;

  List<DlwmsFilterOption> get yearOptions => _data?.yearOptions ?? const [];
  List<DlwmsFilterOption> get subjectOptions =>
      _data?.subjectOptions ?? const [];
  List<DlwmsNotification> get notifications =>
      _data?.notifications ?? const [];
  List<DlwmsMaterial> get materials => _data?.materials ?? const [];

  String get selectedYear => selectedOption(yearOptions)?.value ?? '';
  String get selectedSubject => selectedOption(subjectOptions)?.value ?? '';

  DlwmsClient get _client {
    final auth = _authProvider;
    if (auth == null) {
      throw StateError('Auth provider is not wired to NastavaProvider.');
    }
    return auth.client;
  }

  Future<void> fetch() => _run(fullScreen: true, () async {
        _apply(await _client.fetch(DlwmsClient.nastavaUrl));
      });

  Future<void> refresh() => fetch();

  Future<void> setYear(String value) =>
      _postBack(_yearField, value, current: selectedYear);

  Future<void> setSubject(String value) =>
      _postBack(_subjectField, value, current: selectedSubject);

  Future<DlwmsFile> download(DlwmsMaterial material) async {
    final page = _page;
    final target = material.postBackTarget;
    if (page == null || target == null) {
      throw DlwmsNetworkException('Dokument nije moguće preuzeti.');
    }

    _downloadingTarget = target;
    notifyListeners();
    try {
      return await _client.downloadPostBack(page, target);
    } finally {
      _downloadingTarget = null;
      notifyListeners();
    }
  }

  Future<void> _postBack(String field, String value,
      {required String current}) async {
    final page = _page;
    if (page == null || value == current) return;
    await _run(() async {
      _apply(await _client.postBack(page, field, fields: {field: value}));
    });
  }

  void _apply(DlwmsPage page) {
    _page = page;
    _data = NastavaService.parseNastavaPage(page);
  }

  Future<void> _run(Future<void> Function() action,
      {bool fullScreen = false}) async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    if (fullScreen && _data == null) _state = NastavaProviderState.loading;
    notifyListeners();

    try {
      await action();
      _state = NastavaProviderState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      if (_data == null) _state = NastavaProviderState.error;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
