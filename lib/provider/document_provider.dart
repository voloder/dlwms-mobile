import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/document_service.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/widgets.dart';

enum DokumentiProviderState { loading, loaded, error }

/// Document search (`nastava/dokumenti/pretraga.aspx`). Every filter change is
/// a real postback, so results always match what DLWMS shows on the web.
class DokumentiProvider extends ChangeNotifier {
  static const _prefix = r'ctl00$ContentPlaceHolder1$';
  static const _yearField = '${_prefix}listGodina';
  static const _subjectField = '${_prefix}ddlPredmeti';
  static const _typeField = '${_prefix}listVrsta';
  static const _schoolYearField = '${_prefix}ddlSkolskeGodine';
  static const _keywordField = '${_prefix}txtKljucneRijeci';
  static const _searchButton = '${_prefix}btnTrazi';

  AuthProvider? _authProvider;

  DokumentiProviderState _state = DokumentiProviderState.loading;
  String? _errorMessage;
  DlwmsPage? _page;
  DokumentiPageData? _data;
  bool _busy = false;
  String? _downloadingId;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  DokumentiProviderState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isBusy => _busy;
  String? get downloadingId => _downloadingId;

  List<DlwmsDocument> get documents => _data?.documents ?? const [];
  List<DlwmsFilterOption> get yearOptions => _data?.yearOptions ?? const [];
  List<DlwmsFilterOption> get subjectOptions =>
      _data?.subjectOptions ?? const [];
  List<DlwmsFilterOption> get typeOptions => _data?.typeOptions ?? const [];
  List<DlwmsFilterOption> get schoolYearOptions =>
      _data?.schoolYearOptions ?? const [];

  String get selectedYear => selectedOption(yearOptions)?.value ?? '';
  String get selectedSubject => selectedOption(subjectOptions)?.value ?? '';
  String get selectedType => selectedOption(typeOptions)?.value ?? '';
  String get selectedSchoolYear =>
      selectedOption(schoolYearOptions)?.value ?? '';
  String get keyword => _data?.keyword ?? '';

  int get currentPage => _data?.currentPage ?? 1;
  int get totalPages => _data?.totalPages ?? 1;
  bool get hasNextPage => _data?.nextPageTarget != null;
  bool get hasPreviousPage => _data?.previousPageTarget != null;

  DlwmsClient get _client {
    final auth = _authProvider;
    if (auth == null) {
      throw StateError('Auth provider is not wired to DokumentiProvider.');
    }
    return auth.client;
  }

  /// Opens the search page and runs a search for the default subject.
  Future<void> fetchInitial() async {
    await _run(fullScreen: true, () async {
      final page = await _client.fetch(DlwmsClient.dokumentiUrl);
      _apply(page);
      await _search(page, const {});
    });
  }

  Future<void> refresh() async {
    final page = _page;
    if (page == null) return fetchInitial();
    await _run(() => _search(page, const {}));
  }

  /// Year of study changes the list of subjects, so DLWMS needs a postback
  /// before the search.
  Future<void> setYear(String value) async {
    final page = _page;
    if (page == null || value == selectedYear) return;
    await _run(() async {
      final updated =
          await _client.postBack(page, _yearField, fields: {_yearField: value});
      _apply(updated);
      await _search(updated, const {});
    });
  }

  Future<void> setSubject(String value) =>
      _searchWith({_subjectField: value});

  Future<void> setType(String value) => _searchWith({_typeField: value});

  Future<void> setSchoolYear(String value) =>
      _searchWith({_schoolYearField: value});

  Future<void> setKeyword(String value) =>
      _searchWith({_keywordField: value.trim()});

  Future<void> clearFilters() => _searchWith({
        _typeField: '',
        _schoolYearField: '',
        _keywordField: '',
      });

  Future<void> nextPage() => _goTo(_data?.nextPageTarget);

  Future<void> previousPage() => _goTo(_data?.previousPageTarget);

  /// Downloads [document] and returns the file.
  Future<DlwmsFile> download(DlwmsDocument document) async {
    final page = _page;
    final target = document.postBackTarget;
    if (page == null || target == null) {
      throw DlwmsNetworkException('Dokument nije moguće preuzeti.');
    }

    _downloadingId = document.id;
    notifyListeners();
    try {
      return await _client.downloadPostBack(page, target);
    } finally {
      _downloadingId = null;
      notifyListeners();
    }
  }

  Future<void> _searchWith(Map<String, String> fields) async {
    final page = _page;
    if (page == null) return;
    await _run(() => _search(page, fields));
  }

  Future<void> _search(DlwmsPage page, Map<String, String> fields) async {
    final result = await _client.postBack(
      page,
      '',
      fields: {...fields, _searchButton: 'Traži'},
    );
    _apply(result);
  }

  Future<void> _goTo(String? target) async {
    final page = _page;
    if (page == null || target == null) return;
    await _run(() async => _apply(await _client.postBack(page, target)));
  }

  void _apply(DlwmsPage page) {
    _page = page;
    _data = DocumentService.parseDokumentiPage(page);
  }

  Future<void> _run(Future<void> Function() action,
      {bool fullScreen = false}) async {
    if (_busy) return;
    _busy = true;
    _errorMessage = null;
    if (fullScreen || _data == null) {
      _state = DokumentiProviderState.loading;
    }
    notifyListeners();

    try {
      await action();
      _state = DokumentiProviderState.loaded;
    } catch (e) {
      _errorMessage = e.toString();
      if (_data == null || fullScreen) {
        _state = DokumentiProviderState.error;
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
