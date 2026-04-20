import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/document_service.dart';
import 'package:dlwms_mobile/util/form_templates.dart';
import 'package:flutter/widgets.dart';

enum DokumentiProviderState { loading, loaded, error }

class DokumentiProvider extends ChangeNotifier {
  final dokumentiUrl =
      Uri.parse('https://www.fit.ba/student/nastava/dokumenti/pretraga.aspx');

  AuthProvider? _authProvider;

  DokumentiProviderState _state = DokumentiProviderState.loading;
  String? _errorMessage;

  List<DlwmsDocument> _documents = [];

  List<DlwmsFilterOption> _subjectOptions = [];
  List<DlwmsFilterOption> _typeOptions = [];
  List<DlwmsFilterOption> _schoolYearOptions = [];

  String _searchQuery = '';
  String _selectedSubject = '';
  String _selectedType = '';
  String _selectedSchoolYear = '';

  int _currentPage = 1;
  int _totalPages = 1;

  void update(AuthProvider authProvider) {
    _authProvider = authProvider;
  }

  DokumentiProviderState get state => _state;
  String? get errorMessage => _errorMessage;

  List<DlwmsDocument> get documents => _documents;
  List<DlwmsFilterOption> get subjectOptions => _subjectOptions;
  List<DlwmsFilterOption> get typeOptions => _typeOptions;
  List<DlwmsFilterOption> get schoolYearOptions => _schoolYearOptions;

  String get searchQuery => _searchQuery;
  String get selectedSubject => _selectedSubject;
  String get selectedType => _selectedType;
  String get selectedSchoolYear => _selectedSchoolYear;

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  Future<void> fetchInitial() async {
    _setState(DokumentiProviderState.loading);
    _errorMessage = null;

    try {
      if (_authProvider == null) {
        throw Exception('Auth provider is not wired to DokumentiProvider.');
      }

      final response = await _authProvider!.fetchWithAuth(dokumentiUrl);
      final data = DocumentService.parseDokumentiPage(response.body);

      _subjectOptions = data.subjectOptions;
      _typeOptions = data.typeOptions;
      _schoolYearOptions = data.schoolYearOptions;

      _selectedSubject = _subjectOptions
          .firstWhere(
            (option) => option.isSelected,
            orElse: () => const DlwmsFilterOption(label: '', value: ''),
          )
          .value;

      _documents = data.documents;
      _currentPage = data.currentPage;
      _totalPages = data.totalPages;

      _setState(DokumentiProviderState.loaded);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(DokumentiProviderState.error);
    }
  }


  Future<void> fetchSubjects() async {
    _setState(DokumentiProviderState.loading);
    _errorMessage = null;

    if (_subjectOptions.isEmpty) {
      return fetchInitial();
    }

    try {
      if (_authProvider == null) {
        throw Exception('Auth provider is not wired to DokumentiProvider.');
      }
      final postData = FormTemplates.documentSearchForm(0, 0, 147);
      final response = await _authProvider!.postWithAuth(dokumentiUrl, body: postData);
      final data = DocumentService.parseDokumentiPage(response.body);

      _documents = data.documents;
      _currentPage = data.currentPage;
      _totalPages = data.totalPages;

      _setState(DokumentiProviderState.loaded);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(DokumentiProviderState.error);
    }
  }

  Future<void> refresh() => fetchSubjects();

  void setSearchQuery(String value) {
    _searchQuery = value.trim();
    notifyListeners();
  }

  void setSubject(String value) {
    _selectedSubject = value;
    notifyListeners();
  }

  void setType(String value) {
    _selectedType = value;
    notifyListeners();
  }

  void setSchoolYear(String value) {
    _selectedSchoolYear = value;
    notifyListeners();
  }

  void clearFilters() {
    _selectedSubject = '';
    _selectedType = '';
    _selectedSchoolYear = '';
    notifyListeners();
  }

  String _selectedLabel(List<DlwmsFilterOption> options, String value) {
    return options
            .where((option) => option.value == value)
            .map((option) => option.label)
            .firstOrNull ??
        value;
  }

  void _setState(DokumentiProviderState newState) {
    _state = newState;
    notifyListeners();
  }
}
