import 'dart:io';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/util/cookie_parser.dart';
import 'package:dlwms_mobile/util/form_templates.dart';
import 'package:flutter/cupertino.dart' hide Notification;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:http/http.dart' as http;

enum AuthProviderStatus {
  authenticated,
  unauthenticated,
  authenticating,
  error,
  initial,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._prefs) {
    if(username != null && password != null) {
      login(username!, password!, isAuto: true);
    } else {
      status = AuthProviderStatus.unauthenticated;
    }
  }

  final SharedPreferences _prefs;

  final authUrl = Uri.parse("https://www.fit.ba/student/login.aspx");

  AuthProviderStatus _status = AuthProviderStatus.initial;
  AuthProviderStatus get status => _status;

  String? _cookie;

  set status(AuthProviderStatus state) {
    _status = state;
    notifyListeners();
  }


  set username(String? username) {
    if (username == null) {
      _prefs.remove("username");
    } else {
      _prefs.setString("username", username);
    }
  }

  set password(String? password) {
    if (password == null) {
      _prefs.remove("password");
    } else {
      _prefs.setString("password", password);
    }
  }

  String? get username => _prefs.getString("username");
  String? get password => _prefs.getString("password");

  Map<String, String> get headers => {
        "Accept":
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br, zstd",
        "Content-Type": "application/x-www-form-urlencoded",
        "Origin": "https://www.fit.ba",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "same-origin",
        "Sec-Fetch-User": "?1",
        "Priority": "u=0, i",
        "Pragma": "no-cache",
        "Cache-Control": "no-cache",
        "TE": "trailers",
        if (_cookie != null) "Cookie": _cookie!,
      };

  Future<void> login(String username, String password, {bool isAuto = false}) async {
    status = isAuto ? AuthProviderStatus.initial : AuthProviderStatus.authenticating;

    final requestData = FormTemplates.loginForm(username, password);
    final response =
        await http.post(authUrl, body: requestData.codeUnits, headers: headers);

    _cookie = getCookieFromSetCookieHeader(response.headers["set-cookie"]!);

    debugPrint("Login response status: ${response.statusCode}");
    debugPrint("Login cookie: ${_cookie}");

    if (response.statusCode == 302 && _cookie != null) {
      this.username = username;
      this.password = password;
      status = AuthProviderStatus.authenticated;
    } else {
      status = AuthProviderStatus.error;
    }
  }

  Future<http.Response> fetchWithAuth(Uri url) async {
    if (_cookie == null) {
      throw Exception("No authentication cookie found");
    }

    final response = await http.get(url, headers: headers);

    return response;
  }

  void logout() {
    _cookie = null;
    status = AuthProviderStatus.unauthenticated;
  }
}
