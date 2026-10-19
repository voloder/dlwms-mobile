import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/arhiva_service.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:flutter/widgets.dart';

enum ArhivaState { idle, searching, results, error }

/// Search in the announcement archive (`obavijesti/arhiva.aspx`). Lives only
/// while the search screen is open.
class ArhivaProvider extends ChangeNotifier {
  ArhivaProvider(this._client) {
    _prefetchForm();
  }

  /// Loads the subject list early; a failure is retried on search.
  Future<void> _prefetchForm() async {
    try {
      await _loadForm();
    } catch (_) {}
  }

  final DlwmsClient _client;

  ArhivaState _state = ArhivaState.idle;
  String? _errorMessage;
  DlwmsPage? _formPage;
  DlwmsPage? _resultsPage;
  List<DlwmsFilterOption> _subjects = const [];
  List<DlwmsNotification> _results = const [];
  String? _nextPage;
  bool _loadingMore = false;
  ArhivaQuery _query = const ArhivaQuery();

  ArhivaState get state => _state;
  String? get errorMessage => _errorMessage;
  ArhivaQuery get query => _query;
  List<DlwmsNotification> get results => _results;
  bool get hasMore => _nextPage != null;
  bool get loadingMore => _loadingMore;

  /// Subjects offered by DLWMS (without the empty "all" entry).
  List<DlwmsFilterOption> get subjects =>
      _subjects.where((s) => s.value.isNotEmpty).toList();

  String subjectName(String value) =>
      _subjects.where((s) => s.value == value).firstOrNull?.label ?? '';

  Future<DlwmsPage> _loadForm() async {
    final existing = _formPage;
    if (existing != null) return existing;
    final page = await _client.fetch(DlwmsClient.archiveUrl);
    _formPage = page;
    _subjects = ArhivaService.parse(page).subjects;
    notifyListeners();
    return page;
  }

  void updateQuery(ArhivaQuery query) {
    _query = query;
    notifyListeners();
  }

  Future<void> search([ArhivaQuery? query]) async {
    if (query != null) _query = query;
    if (_query.isEmpty) {
      _state = ArhivaState.idle;
      _results = const [];
      _nextPage = null;
      notifyListeners();
      return;
    }

    _state = ArhivaState.searching;
    _errorMessage = null;
    notifyListeners();

    try {
      final form = await _loadForm();
      final page = await _client.postBack(form, '', fields: _query.toFields());
      final data = ArhivaService.parse(page,
          subjectName: subjectName(_query.subject));
      _resultsPage = page;
      _results = data.results;
      _nextPage = data.nextPage;
      _state = ArhivaState.results;
    } catch (e) {
      // The form page may have expired; load a fresh one next time.
      _formPage = null;
      _errorMessage = e.toString();
      _state = ArhivaState.error;
    }
    notifyListeners();
  }

  /// Next page of results (20 per page).
  Future<void> loadMore() async {
    final page = _resultsPage;
    final target = _nextPage;
    if (page == null || target == null || _loadingMore) return;

    _loadingMore = true;
    notifyListeners();
    try {
      final next = await _client.postBack(page, target);
      final data = ArhivaService.parse(next,
          subjectName: subjectName(_query.subject));
      final known = {for (final r in _results) r.id};
      _results = [..._results, ...data.results.where((r) => !known.contains(r.id))];
      _resultsPage = next;
      _nextPage = data.results.isEmpty ? null : data.nextPage;
    } catch (_) {
      _nextPage = null;
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Requests can finish after the search screen was closed.
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }
}
