// Renders the real app, fed with saved DLWMS pages instead of fit.ba, and
// writes PNG screenshots of every screen in light and dark mode.
//
// Run with:  flutter test --update-goldens screenshots/
// Output:    screenshots/goldens/*.png
//
// Not part of the normal `flutter test` run (which only covers test/).

import 'dart:io';

import 'package:dlwms_mobile/app.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

Future<void> _loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final dir = Directory('$root/bin/cache/artifacts/material_fonts');

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final name in files) {
      final file = File('${dir.path}/$name');
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
    }
    await loader.load();
  }

  await load('Roboto', [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
    'Roboto-Light.ttf',
    'Roboto-Black.ttf',
    'Roboto-Thin.ttf',
  ]);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

/// Moves the announcement dates so the newest one is about an hour old,
/// which makes relative times ("prije 1 h") look realistic.
String _freshDates(String html) {
  final pattern = RegExp(r'(\d{2})\.(\d{2})\.(\d{4}) (\d{2}):(\d{2})');
  final dates = pattern.allMatches(html).map((m) => DateTime(
        int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!),
        int.parse(m[4]!), int.parse(m[5]!)));
  if (dates.isEmpty) return html;
  final newest = dates.reduce((a, b) => a.isAfter(b) ? a : b);
  final shift = DateTime.now()
      .subtract(const Duration(minutes: 75))
      .difference(newest);
  final format = DateFormat('dd.MM.yyyy HH:mm');
  return html.replaceAllMapped(pattern, (m) {
    final date = DateTime(int.parse(m[3]!), int.parse(m[2]!),
        int.parse(m[1]!), int.parse(m[4]!), int.parse(m[5]!));
    return format.format(date.add(shift));
  });
}

DlwmsClient _fixtureClient() {
  final home = _freshDates(readReference('Početna'));
  final nastava = _freshDates(readReference('Nastava'));
  final dokumenti = readReference('Dokumenti');

  return DlwmsClient(
    httpClient: MockClient((request) async {
      final path = request.url.path.toLowerCase();
      // `http.Response` encodes the body using the charset in the header.
      http.Response page(String body) => http.Response(
            body,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );

      if (path.endsWith('/login.aspx')) {
        if (request.method == 'POST') {
          return http.Response('', 302, headers: {
            'location': '/student/default.aspx',
            'set-cookie': 'SID=fixture; path=/',
          });
        }
        return page(loginPage);
      }
      if (path.endsWith('/default.aspx')) return page(home);
      if (path.endsWith('/nastava/index.aspx')) return page(nastava);
      if (path.endsWith('/pretraga.aspx')) return page(dokumenti);
      if (path.endsWith('/prisustvo.aspx')) return page(prisustvoPage);
      if (path.endsWith('/uspjeh.aspx')) return page(uspjehPage);
      return http.Response('not found', 404);
    }),
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  required Map<String, Object> prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final sharedPrefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(buildApp(sharedPrefs, client: _fixtureClient()));
  await _settle(tester);
}

/// Lets network futures and animations finish without waiting on endless
/// progress indicators.
Future<void> _settle(WidgetTester tester, [int frames = 12]) async {
  for (var i = 0; i < frames; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  const loggedIn = <String, Object>{
    'username': 'IB230042',
    'password': 'fixture',
    'background_check_enabled': false,
  };

  for (final mode in ['light', 'dark']) {
    testWidgets('screens ($mode)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);

      await _pumpApp(tester, prefs: {...loggedIn, 'theme_mode': mode});
      await _shot(tester, '${mode}_1_pocetna');

      Future<void> openTab(String label, String name) async {
        await tester.tap(find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ));
        await _settle(tester);
        await _shot(tester, name);
      }

      await openTab('Nastava', '${mode}_2_nastava');
      await openTab('Dokumenti', '${mode}_3_dokumenti');
      await openTab('Prisustva', '${mode}_4_prisustva');
      await openTab('Uspjeh', '${mode}_5_uspjeh');

      await tester.tap(find.byTooltip('Postavke'));
      await _settle(tester);
      await _shot(tester, '${mode}_6_postavke');

      // Unmount so provider timers are cancelled before the test ends.
      await tester.pumpWidget(const SizedBox());
      await _settle(tester, 2);
    });
  }

  testWidgets('login and custom colours', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await _pumpApp(tester, prefs: {'theme_mode': 'light'});
    await _shot(tester, 'light_0_login');
    await tester.pumpWidget(const SizedBox());

    await _pumpApp(tester, prefs: {
      ...loggedIn,
      'theme_mode': 'dark',
      'theme_seed': 0xFF00897B,
    });
    await _shot(tester, 'custom_teal_pocetna');
    await tester.pumpWidget(const SizedBox());
    await _settle(tester, 2);
  });
}
