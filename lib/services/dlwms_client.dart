import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// Thrown when DLWMS rejects the supplied credentials.
class DlwmsAuthException implements Exception {
  DlwmsAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Thrown when DLWMS cannot be reached or returns something unexpected.
class DlwmsNetworkException implements Exception {
  DlwmsNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A fetched DLWMS page together with its parsed DOM.
class DlwmsPage {
  DlwmsPage(this.url, this.html) : document = html_parser.parse(html);

  final Uri url;
  final String html;
  final dom.Document document;

  /// Resolves a (possibly relative) link found on this page.
  Uri resolve(String href) => url.resolve(href);

  /// URL the page's WebForms form posts back to.
  Uri get formAction {
    final action = document.querySelector('form')?.attributes['action'];
    if (action == null || action.trim().isEmpty) return url;
    return url.resolve(action.trim());
  }

  /// Collects every field the browser would submit for this page's form
  /// (hidden ASP.NET state, selected options, text inputs, checked boxes).
  ///
  /// Buttons are intentionally skipped; add the one you want to "click"
  /// explicitly when posting back.
  Map<String, String> formFields() {
    final fields = <String, String>{};

    for (final input in document.querySelectorAll('input')) {
      final name = input.attributes['name'];
      if (name == null || name.isEmpty) continue;
      if (input.attributes.containsKey('disabled')) continue;

      final type = (input.attributes['type'] ?? 'text').toLowerCase();
      switch (type) {
        case 'submit':
        case 'image':
        case 'button':
        case 'reset':
        case 'file':
          continue;
        case 'checkbox':
        case 'radio':
          if (!input.attributes.containsKey('checked')) continue;
          fields[name] = input.attributes['value'] ?? 'on';
        default:
          fields[name] = input.attributes['value'] ?? '';
      }
    }

    for (final select in document.querySelectorAll('select')) {
      final name = select.attributes['name'];
      if (name == null || name.isEmpty) continue;
      if (select.attributes.containsKey('disabled')) continue;

      final options = select.querySelectorAll('option');
      if (options.isEmpty) continue;
      final selected = options.firstWhere(
        (option) => option.attributes.containsKey('selected'),
        orElse: () => options.first,
      );
      fields[name] = selected.attributes['value'] ?? selected.text.trim();
    }

    for (final textarea in document.querySelectorAll('textarea')) {
      final name = textarea.attributes['name'];
      if (name == null || name.isEmpty) continue;
      fields[name] = textarea.text;
    }

    return fields;
  }
}

/// A file returned by DLWMS (e.g. a downloaded document).
class DlwmsFile {
  const DlwmsFile({
    required this.fileName,
    required this.bytes,
    this.contentType,
  });

  final String fileName;
  final Uint8List bytes;
  final String? contentType;
}

class _RawResponse {
  _RawResponse(this.url, this.response);

  final Uri url;
  final http.Response response;

  String get body => utf8.decode(response.bodyBytes, allowMalformed: true);

  String? get contentType => response.headers['content-type'];

  bool get isHtml {
    final type = contentType?.toLowerCase() ?? 'text/html';
    return type.contains('text/html') || type.contains('xhtml');
  }
}

/// Talks to the DLWMS student portal (ASP.NET WebForms) the way a browser
/// would: keeps cookies, follows redirects, reads hidden form state from each
/// page and re-authenticates automatically when the session expires.
///
/// Pure Dart (no Flutter imports) so it can also run inside the background
/// service isolate.
class DlwmsClient {
  DlwmsClient({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  static final Uri baseUrl = Uri.parse('https://www.fit.ba/student/');
  static final Uri loginUrl = baseUrl.resolve('login.aspx');
  static final Uri logoutUrl = baseUrl.resolve('logout.aspx');
  static final Uri homeUrl = baseUrl.resolve('default.aspx');
  static final Uri nastavaUrl = baseUrl.resolve('nastava/index.aspx');
  static final Uri dokumentiUrl =
      baseUrl.resolve('nastava/dokumenti/pretraga.aspx');
  static final Uri prisustvoUrl = baseUrl.resolve('nastava/prisustvo.aspx');
  static final Uri uspjehUrl = baseUrl.resolve('evaluacija/uspjeh.aspx');
  static final Uri examTermsUrl = baseUrl.resolve('rokovi/index.aspx');
  static final Uri testsUrl = baseUrl.resolve('EUSASStudentHome.aspx');
  static final Uri archiveUrl = baseUrl.resolve('obavijesti/arhiva.aspx');

  /// FIT is option 1 in the login page's institution dropdown.
  static const String institutionFit = '1';

  static const Duration _timeout = Duration(seconds: 30);
  static const String _userAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36';

  final http.Client _http;
  final Map<String, String> _cookies = {};

  String? _username;
  String? _password;
  bool _loggedIn = false;
  Future<void>? _loginInFlight;

  bool get isLoggedIn => _loggedIn;

  /// Stores credentials so the client can log in (again) on demand.
  void setCredentials(String username, String password) {
    if (username != _username || password != _password) {
      _loggedIn = false;
    }
    _username = username;
    _password = password;
  }

  /// Logs in with [username]/[password]. Throws [DlwmsAuthException] when the
  /// credentials are rejected and [DlwmsNetworkException] on connection issues.
  Future<void> login(String username, String password) {
    setCredentials(username, password);
    _loggedIn = false;
    return _ensureLoggedIn();
  }

  Future<void> _ensureLoggedIn() {
    if (_loggedIn) return Future.value();
    return _loginInFlight ??= _performLogin().whenComplete(() {
      _loginInFlight = null;
    });
  }

  Future<void> _performLogin() async {
    final username = _username;
    final password = _password;
    if (username == null || password == null) {
      throw DlwmsAuthException('Niste prijavljeni.');
    }

    _cookies.clear();

    final loginGet = await _send('GET', loginUrl);
    final loginPage = DlwmsPage(loginGet.url, loginGet.body);

    final fields = loginPage.formFields()
      ..remove('chkZapamtiMe')
      ..['txtBrojDosijea'] = username
      ..['txtLozinka'] = password
      ..['listInstitucija'] = institutionFit
      ..['btnPrijava'] = 'Prijava';

    final response =
        await _send('POST', loginPage.formAction, form: fields);

    if (_isLoginUrl(response.url)) {
      throw DlwmsAuthException('Neispravan broj indeksa ili lozinka.');
    }

    _loggedIn = true;
  }

  /// GETs an authenticated page.
  Future<DlwmsPage> fetch(Uri url) async {
    final response = await _authenticated('GET', url);
    return DlwmsPage(response.url, response.body);
  }

  /// Simulates `__doPostBack(eventTarget, eventArgument)` on [page], i.e. a
  /// click on a link/dropdown change in the browser. [fields] override the
  /// values read from the page (selected dropdown values, button clicks, ...).
  Future<DlwmsPage> postBack(
    DlwmsPage page,
    String eventTarget, {
    Map<String, String> fields = const {},
    String eventArgument = '',
  }) async {
    final response = await _authenticated(
      'POST',
      page.formAction,
      form: _postBackFields(page, eventTarget, eventArgument, fields),
    );

    if (!response.isHtml) {
      throw DlwmsNetworkException('DLWMS je vratio neočekivan odgovor.');
    }
    return DlwmsPage(response.url, response.body);
  }

  /// Performs a postback that is expected to return a file (document links).
  Future<DlwmsFile> downloadPostBack(
    DlwmsPage page,
    String eventTarget, {
    Map<String, String> fields = const {},
  }) async {
    final response = await _authenticated(
      'POST',
      page.formAction,
      form: _postBackFields(page, eventTarget, '', fields),
    );

    if (response.isHtml) {
      throw DlwmsNetworkException('Dokument trenutno nije dostupan.');
    }

    return DlwmsFile(
      fileName: _fileNameFrom(response),
      bytes: response.response.bodyBytes,
      contentType: response.contentType,
    );
  }

  /// Best-effort server logout; always clears the local session.
  Future<void> logout() async {
    try {
      if (_loggedIn) await _send('GET', logoutUrl);
    } catch (_) {
      // Ignore: we're dropping the session either way.
    } finally {
      _cookies.clear();
      _loggedIn = false;
      _username = null;
      _password = null;
    }
  }

  void close() => _http.close();

  Map<String, String> _postBackFields(
    DlwmsPage page,
    String eventTarget,
    String eventArgument,
    Map<String, String> overrides,
  ) {
    return page.formFields()
      ..['__EVENTTARGET'] = eventTarget
      ..['__EVENTARGUMENT'] = eventArgument
      ..addAll(overrides);
  }

  /// Sends a request, logging in first if needed and once more if DLWMS
  /// bounces us to the login page because the session expired.
  Future<_RawResponse> _authenticated(
    String method,
    Uri url, {
    Map<String, String>? form,
  }) async {
    await _ensureLoggedIn();

    var response = await _send(method, url, form: form);
    if (_isLoginUrl(response.url)) {
      _loggedIn = false;
      await _ensureLoggedIn();
      response = await _send(method, url, form: form);
      if (_isLoginUrl(response.url)) {
        _loggedIn = false;
        throw DlwmsAuthException('Sesija je istekla. Prijavite se ponovo.');
      }
    }
    return response;
  }

  /// Low-level request with manual redirect handling so cookies set on
  /// intermediate 302 responses (login, downloads) are kept.
  Future<_RawResponse> _send(
    String method,
    Uri url, {
    Map<String, String>? form,
  }) async {
    var currentUrl = url;
    var currentMethod = method;
    var currentForm = form;

    for (var hop = 0; hop < 10; hop++) {
      final request = http.Request(currentMethod, currentUrl)
        ..followRedirects = false
        ..headers.addAll(_headersFor(currentUrl));
      if (currentForm != null) {
        request.bodyFields = currentForm;
      }

      final http.Response response;
      try {
        final streamed = await _http.send(request).timeout(_timeout);
        response = await http.Response.fromStream(streamed).timeout(_timeout);
      } on TimeoutException {
        throw DlwmsNetworkException('DLWMS ne odgovara. Pokušajte kasnije.');
      } on http.ClientException catch (e) {
        throw DlwmsNetworkException('Greška u konekciji: ${e.message}');
      } catch (e) {
        throw DlwmsNetworkException('Greška u konekciji: $e');
      }

      _storeCookies(response);

      final status = response.statusCode;
      if (status >= 300 && status < 400) {
        final location = response.headers['location'];
        if (location == null) return _RawResponse(currentUrl, response);
        currentUrl = currentUrl.resolve(location);
        currentMethod = 'GET';
        currentForm = null;
        continue;
      }

      if (status >= 500) {
        throw DlwmsNetworkException('DLWMS server je vratio grešku ($status).');
      }

      return _RawResponse(currentUrl, response);
    }

    throw DlwmsNetworkException('Previše preusmjeravanja.');
  }

  Map<String, String> _headersFor(Uri url) => {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'bs,hr;q=0.9,en;q=0.8',
        'Origin': '${url.scheme}://${url.host}',
        'Referer': url.toString(),
        if (_cookies.isNotEmpty)
          'Cookie':
              _cookies.entries.map((e) => '${e.key}=${e.value}').join('; '),
      };

  /// `package:http` joins multiple Set-Cookie headers with commas; split only
  /// on commas that start a new `name=value` pair (not those inside Expires).
  static final RegExp _cookieSplitter = RegExp(r',(?=\s*[^;,=\s]+=)');

  void _storeCookies(http.Response response) {
    final header = response.headers['set-cookie'];
    if (header == null || header.isEmpty) return;

    for (final cookie in header.split(_cookieSplitter)) {
      final pair = cookie.split(';').first.trim();
      final eq = pair.indexOf('=');
      if (eq <= 0) continue;

      final name = pair.substring(0, eq).trim();
      final value = pair.substring(eq + 1).trim();
      final expired = RegExp(r'expires=[^;]*19\d\d', caseSensitive: false)
          .hasMatch(cookie);

      if (value.isEmpty || expired) {
        _cookies.remove(name);
      } else {
        _cookies[name] = value;
      }
    }
  }

  static bool _isLoginUrl(Uri url) =>
      url.path.toLowerCase().endsWith('/login.aspx');

  static String _fileNameFrom(_RawResponse response) {
    final disposition = response.response.headers['content-disposition'] ?? '';

    String? name;
    final encoded = RegExp(r"filename\*\s*=\s*(?:UTF-8'')?([^;]+)",
            caseSensitive: false)
        .firstMatch(disposition);
    if (encoded != null) {
      name = Uri.decodeComponent(encoded.group(1)!.trim().replaceAll('"', ''));
    } else {
      final plain = RegExp(r'filename\s*=\s*"?([^";]+)"?', caseSensitive: false)
          .firstMatch(disposition);
      if (plain != null) {
        name = plain.group(1)!.trim();
        // Headers are decoded as Latin-1; repair UTF-8 file names.
        try {
          name = utf8.decode(latin1.encode(name));
        } catch (_) {}
      }
    }

    name ??= response.url.pathSegments.isNotEmpty
        ? response.url.pathSegments.last
        : 'dokument';

    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
