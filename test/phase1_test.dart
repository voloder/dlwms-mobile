import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/services/arhiva_service.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/exam_reminders.dart';
import 'package:dlwms_mobile/services/ispiti_service.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:dlwms_mobile/services/seen_store.dart';
import 'package:dlwms_mobile/services/watchers.dart';
import 'package:dlwms_mobile/util/bs_dates.dart';
import 'package:dlwms_mobile/util/credentials.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DlwmsPage _html(String path, String body) => DlwmsPage(
      Uri.parse('https://www.fit.ba/student/$path'),
      '<html><body><form method="post" action="./${path.split('/').last}">'
      '$body</form></body></html>',
    );

void main() {
  group('IspitiService.parseTerms', () {
    const page = '''
      <select name="ctl00\$ContentPlaceHolder1\$listRokovi" id="listRokovi">
        <option selected="selected" value="760">Apsolventski rok oktobar</option>
        <option value="751">Septembarski rok</option>
      </select>
      <table id="gridTermini">
        <tr class="Header"><td>Naslov</td><td>Datum</td><td>Vrijeme</td><td>Zauzeto mjesta</td><td>&nbsp;</td></tr>
        <tr class="grid"><td><span id="lblPredmetNaziv">Razvoj softvera II </span></td>
          <td>26.10.2026</td><td>12:00</td><td align="center">&nbsp;</td>
          <td><input id="chkSelect" type="checkbox" name="a" /></td></tr>
        <tr class="grid"><td><span id="lblPredmetNaziv">Razvoj softvera I </span></td>
          <td>19.10.2026</td><td>11:00</td><td align="center">12</td>
          <td><input id="chkSelect" type="checkbox" name="b" checked="checked" disabled="disabled" /></td></tr>
      </table>''';

    test('parses periods and terms, sorted by date', () {
      final data = IspitiService.parseTerms(_html('rokovi/index.aspx', page));

      expect(data.periods.map((p) => p.value), ['760', '751']);
      expect(data.terms.length, 2);

      final first = data.terms.first;
      expect(first.subject, 'Razvoj softvera I');
      expect(first.dateTime, DateTime(2026, 10, 19, 11, 0));
      expect(first.seats, '12');
      expect(first.registered, isTrue);
      expect(first.selectable, isFalse);
      expect(first.periodId, '760');
      expect(first.id, '760|Razvoj softvera I|19.10.2026|11:00');

      final second = data.terms.last;
      expect(second.subject, 'Razvoj softvera II');
      expect(second.registered, isFalse);
      expect(second.selectable, isTrue);
      expect(second.seats, '');
    });
  });

  group('IspitiService.parseTests', () {
    const active = '''
      <div id="currentActiveTestsBlock" style="display:block;">
      <table id="gvIndexCurrentlyActiveTests">
        <tr><th>Predmet</th><th>Naziv</th><th>Trajanje</th><th>Od</th><th>Do</th><th></th></tr>
        <tr><td>Razvoj softvera I</td><td>RSI :: 19.10.2026</td><td>20</td>
            <td>19.10.2026 11:14:00</td><td>19.10.2026 15:36:00</td><td></td></tr>
      </table></div>''';
    const previous = '''
      <table id="gvIndexPreviousTests">
        <tr><th>Predmet</th><th>Naziv</th><th>Datum</th><th>Uspjeh (%)</th><th></th></tr>
        <tr><td>Analiza i dizajn softvera</td><td>ADS_6JUL26</td><td>6.7.2026 10:20:17</td><td>62.16</td><td></td></tr>
        <tr><td colspan="5"><table><tr><td><span>1</span></td><td><a href="javascript:__doPostBack('x','Page\$2')">2</a></td></tr></table></td></tr>
      </table>''';

    test('parses active tests and results, skipping the pager', () {
      final data = IspitiService.parseTests(
          _html('EUSASStudentHome.aspx', active + previous));

      expect(data.active.single.subject, 'Razvoj softvera I');
      expect(data.active.single.durationMinutes, 20);
      expect(data.active.single.to, DateTime(2026, 10, 19, 15, 36));

      expect(data.results.length, 1);
      expect(data.results.single.name, 'ADS_6JUL26');
      expect(data.results.single.percentage, closeTo(62.16, 0.001));
      expect(data.results.single.dateTime, DateTime(2026, 7, 6, 10, 20));
    });

    test('ignores the active table when its block is hidden', () {
      final hidden = active.replaceFirst('display:block;', 'display:none;');
      final data =
          IspitiService.parseTests(_html('EUSASStudentHome.aspx', hidden));
      expect(data.active, isEmpty);
    });
  });

  test('sidebar documents use the full title from the tooltip', () {
    final docs = IspitiService.parseSidebarDocuments(_html('default.aspx', '''
      <table id="gridMaterijali"><tr><td><table><tr>
        <td><img id="imgType" src="css/mime/box_rar.png" /></td>
        <td><a id="lbtnNaslov" title="MPP - V2 - Analiza poslovanja - 2026/2027"
               href="javascript:__doPostBack('ctl00\$gridMaterijali\$ctl03\$lbtnNaslov','')">MPP - V2 - Analiza...</a>
            <br /><span id="lblPredmetNaziv">MPP</span></td>
      </tr></table></td></tr><tr><td><span>1</span></td></tr></table>'''));

    expect(docs.single.title, 'MPP - V2 - Analiza poslovanja - 2026/2027');
    expect(docs.single.subject, 'MPP');
  });

  group('pagers', () {
    test('home announcements: next page after the current one', () {
      final page = _html('default.aspx', '''
        <table id="dgObavijesti">
          <tr><td><ul class="newslist"><li><a id="lnkNaslov" href="obavijesti/opsirnije.aspx?sqs=1">A</a>
            <span id="lblDatum">01.10.2026 10:00 -</span></li></ul></td></tr>
          <tr><td><a href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgObavijesti\$ctl14\$ctl00','')">1</a>
            <span>2</span>
            <a href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgObavijesti\$ctl14\$ctl02','')">3</a>
            <a href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgObavijesti\$ctl14\$ctl10','')">...</a></td></tr>
        </table>''');

      final pager = NotificationService.parseHomePager(page);
      expect(pager.map((l) => l.label), ['1', '2', '3', '...']);
      expect(nextPageTarget(pager),
          r'ctl00$ContentPlaceHolder1$dgObavijesti$ctl14$ctl02');
    });

    test('a single page has no pager', () {
      final page = _html('default.aspx', '''
        <table id="dgObavijesti"><tr><td><span>1</span></td></tr></table>''');
      expect(NotificationService.parseHomePager(page), isEmpty);
    });
  });

  group('ArhivaService', () {
    test('parses results, subjects and the next page', () {
      final page = _html('obavijesti/arhiva.aspx', '''
        <select name="x" id="listPredmet"><option value=""></option>
          <option value="157" selected="selected">Razvoj softvera II</option></select>
        <table id="dgArhiva">
          <tr class="grid"><td>18.10.2026 22:12</td>
            <td><a id="lnkNaslov" href="opsirnije.aspx?sqs=AB%2bC">RSI :: Ispitni termin</a></td></tr>
          <tr class="pgr"><td colspan="2"><span>1</span>&nbsp;<a href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgArhiva\$ctl24\$ctl01','')">2</a></td></tr>
        </table>''');

      final data = ArhivaService.parse(page, subjectName: 'Razvoj softvera II');
      expect(data.subjects.length, 2);
      expect(data.results.single.title, 'RSI :: Ispitni termin');
      expect(data.results.single.dateTime, DateTime(2026, 10, 18, 22, 12));
      expect(data.results.single.subject, 'Razvoj softvera II');
      expect(data.results.single.url,
          'https://www.fit.ba/student/obavijesti/opsirnije.aspx?sqs=AB%2BC');
      expect(data.nextPage, r'ctl00$ContentPlaceHolder1$dgArhiva$ctl24$ctl01');
    });

    test('query becomes the DLWMS form fields', () {
      final fields = ArhivaQuery(
        words: ' ispit ',
        subject: '157',
        anyWord: true,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 10, 5),
      ).toFields();

      expect(fields[r'ctl00$ContentPlaceHolder1$txtRijeci'], 'ispit');
      expect(fields[r'ctl00$ContentPlaceHolder1$listPredmet'], '157');
      expect(fields[r'ctl00$ContentPlaceHolder1$listOperator'], 'OR');
      expect(fields[r'ctl00$ContentPlaceHolder1$txtDatumOd'], '01.09.2026');
      expect(fields[r'ctl00$ContentPlaceHolder1$txtDatumDo'], '05.10.2026');
      expect(fields[r'ctl00$ContentPlaceHolder1$btnTrazi'], 'Traži');
      expect(const ArhivaQuery().isEmpty, isTrue);
    });
  });

  group('SeenStore', () {
    test('baseline first, then only new items', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      String id(String s) => s;

      expect(await SeenStore.detectNew(prefs, 'k', ['a', 'b'], id), isEmpty);
      expect(await SeenStore.detectNew(prefs, 'k', ['c', 'a', 'b'], id), ['c']);
      expect(await SeenStore.detectNew(prefs, 'k', ['c', 'a'], id), isEmpty);
      expect(await SeenStore.detectNew(prefs, 'k', const <String>[], id),
          isEmpty);
      expect(prefs.getStringList('k'), containsAll(['a', 'b', 'c']));
    });
  });

  group('NotificationTarget', () {
    test('round-trips announcements and tabs', () {
      const url = 'https://www.fit.ba/student/obavijesti/opsirnije.aspx?sqs=A%2bB';
      final a = NotificationTarget.decode(
          const NotificationTarget.announcement(url).encode())!;
      expect(a.announcementUrl, url);
      expect(Uri.parse(a.location).path, '/home/obavijest');
      expect(Uri.parse(a.location).queryParameters['url'], url);

      final t = NotificationTarget.decode(
          const NotificationTarget.tab(AppTab.ispiti).encode())!;
      expect(t.tab, AppTab.ispiti);
      expect(t.location, '/home?tab=ispiti');
    });

    test('understands payloads from older versions', () {
      final legacy = NotificationTarget.decode('https://www.fit.ba/x');
      expect(legacy?.announcementUrl, 'https://www.fit.ba/x');
      expect(NotificationTarget.decode(null), isNull);
      expect(NotificationTarget.decode('tab|nepostoji'), isNull);
    });
  });

  group('ExamReminders.reminderTime', () {
    ExamTerm term(DateTime at) => ExamTerm(
          subject: 'Razvoj softvera II',
          dateTime: at,
          dateText: '',
          timeText: '12:00',
          seats: '',
          registered: false,
          selectable: true,
          periodId: '760',
        );

    test('evening before when possible', () {
      final now = DateTime(2026, 10, 19, 9, 0);
      expect(
        ExamReminders.reminderTime(term(DateTime(2026, 10, 26, 12)), now: now),
        DateTime(2026, 10, 25, 18),
      );
    });

    test('two hours before when the evening has passed', () {
      final now = DateTime(2026, 10, 25, 20, 0);
      expect(
        ExamReminders.reminderTime(term(DateTime(2026, 10, 26, 12)), now: now),
        DateTime(2026, 10, 26, 10),
      );
    });

    test('none when the exam is too close', () {
      final now = DateTime(2026, 10, 26, 11, 0);
      expect(
        ExamReminders.reminderTime(term(DateTime(2026, 10, 26, 12)), now: now),
        isNull,
      );
    });
  });

  test('BsDates.daysFromNow', () {
    final now = DateTime(2026, 10, 19, 23, 50);
    expect(BsDates.daysFromNow(DateTime(2026, 10, 19, 8), now: now), 'danas');
    expect(BsDates.daysFromNow(DateTime(2026, 10, 20, 8), now: now), 'sutra');
    expect(BsDates.daysFromNow(DateTime(2026, 10, 22), now: now), 'za 3 dana');
    expect(BsDates.daysFromNow(DateTime(2026, 11, 9), now: now), 'za 21 dan');
    expect(BsDates.daysFromNow(DateTime(2026, 10, 18), now: now), 'jučer');
    expect(BsDates.weekdayShort(DateTime(2026, 10, 19)), 'pon');
    expect(BsDates.monthShort(DateTime(2026, 10, 19)), 'okt');
  });

  test('percent formatting and stable ids', () {
    expect(DlwmsWatchers.formatPercent(62.16), '62,16 %');
    expect(DlwmsWatchers.formatPercent(71.5), '71,5 %');
    expect(DlwmsWatchers.formatPercent(88), '88 %');

    final id = LocalNotifications.idFor('dlwms_podsjetnici|760|X|1.1.2026|10:00');
    expect(id, LocalNotifications.idFor('dlwms_podsjetnici|760|X|1.1.2026|10:00'));
    expect(id, isNonNegative);
    expect(id, isNot(LocalNotifications.idFor('dlwms_podsjetnici|other')));
  });

  group('CredentialStore', () {
    test('moves a plain-text password into secure storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({
        PrefKeys.username: 'IB230042',
        PrefKeys.legacyPassword: 'tajna',
      });
      final prefs = await SharedPreferences.getInstance();

      final credentials = await CredentialStore.read(prefs);
      expect(credentials?.username, 'IB230042');
      expect(credentials?.password, 'tajna');
      expect(prefs.getString(PrefKeys.legacyPassword), isNull);

      // Still readable afterwards, now from secure storage only.
      expect((await CredentialStore.read(prefs))?.password, 'tajna');

      await CredentialStore.clearPassword(prefs);
      expect(await CredentialStore.read(prefs), isNull);
      expect(prefs.getString(PrefKeys.username), 'IB230042');
    });

    test('save and read', () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await CredentialStore.read(prefs), isNull);
      await CredentialStore.save(prefs, 'IB1', 'pw');
      expect((await CredentialStore.read(prefs))?.password, 'pw');
      expect(prefs.getString(PrefKeys.legacyPassword), isNull);
    });
  });
}
