import 'dart:io';

import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/document_service.dart';
import 'package:dlwms_mobile/services/nastava_service.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/services/obavijesti_watcher.dart';
import 'package:dlwms_mobile/services/prisustvo_service.dart';
import 'package:dlwms_mobile/services/uspjeh_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DlwmsPage _reference(String name, String path) => DlwmsPage(
      Uri.parse('https://www.fit.ba/student/$path'),
      File('references/DLWMS - $name.htm').readAsStringSync(),
    );

DlwmsPage _html(String path, String body) => DlwmsPage(
      Uri.parse('https://www.fit.ba/student/$path'),
      '<html><body><form method="post" action="./${path.split('/').last}">'
      '$body</form></body></html>',
    );

void main() {
  group('DlwmsPage.formFields', () {
    test('collects hidden state, selections and checked boxes only', () {
      final page = _html('nastava/index.aspx', '''
        <input type="hidden" name="__VIEWSTATE" value="abc" />
        <input type="hidden" name="__EVENTTARGET" value="" />
        <input name="ctl00\$txtSearch" type="text" value="Pretraga" />
        <input type="submit" name="btnTrazi" value="Traži" />
        <input type="image" name="ctl00\$Image1" src="x.gif" />
        <input type="checkbox" name="chkOn" checked="checked" />
        <input type="checkbox" name="chkOff" />
        <input type="checkbox" name="chkDisabled" checked disabled />
        <select name="listGodina"><option value="1">1</option>
          <option selected="selected" value="2">2</option></select>
        <select name="noSelection"><option value="7">A</option></select>
      ''');

      final fields = page.formFields();

      expect(fields['__VIEWSTATE'], 'abc');
      expect(fields['__EVENTTARGET'], '');
      expect(fields[r'ctl00$txtSearch'], 'Pretraga');
      expect(fields['chkOn'], 'on');
      expect(fields['listGodina'], '2');
      expect(fields['noSelection'], '7');
      expect(fields.containsKey('btnTrazi'), isFalse);
      expect(fields.containsKey(r'ctl00$Image1'), isFalse);
      expect(fields.containsKey('chkOff'), isFalse);
      expect(fields.containsKey('chkDisabled'), isFalse);
      expect(page.formAction.toString(),
          'https://www.fit.ba/student/nastava/index.aspx');
    });
  });

  group('NotificationService', () {
    test('parses the home page announcements', () {
      final page = _reference('Početna', 'default.aspx');
      final list = NotificationService.parseNotifications(page);

      expect(list, isNotEmpty);
      final first = list.first;
      expect(first.title, 'Nastava za 08.04.');
      expect(first.subject, 'Kompjuterska grafika');
      expect(first.author, 'Senad Rahimić');
      expect(first.authorEmail, 'senad.Rahimic@unmo.ba');
      expect(first.dateTime, DateTime(2026, 4, 7, 11, 27));
      expect(first.id, '07.04.2026 11:27|Nastava za 08.04.');
      expect(first.url, contains('obavijesti/opsirnije.aspx?sqs='));
      expect(first.content, contains('online'));
      // <br> becomes a line break.
      expect(first.content, contains('\n'));
    });

    test('resolves relative links against the page URL', () {
      final page = _html('default.aspx', '''
        <table id="dgObavijesti"><tr><td><ul class="newslist"><li>
          <a id="lnkNaslov" class="linkButton"
             href="obavijesti/opsirnije.aspx?sqs=AB%2bC">Naslov</a>
          <span id="lblDatum" class="meta">16.10.2026 22:14 -</span>
          <span id="lblPredmet" class="meta"></span>
          <a class="meta" href="mailto:x@edu.fit.ba">Profesor</a>
          <div class="abstract"> Tekst </div>
        </li></ul></td></tr></table>
      ''');

      final n = NotificationService.parseNotifications(page).single;
      expect(n.url,
          'https://www.fit.ba/student/obavijesti/opsirnije.aspx?sqs=AB%2BC');
      expect(n.subject, 'Opće');
      expect(n.dateTime, DateTime(2026, 10, 16, 22, 14));
    });

    test('parses the full announcement page', () {
      final page = _html('obavijesti/opsirnije.aspx', '''
        <span id="lblPredmetNaziv">Razvoj softvera II</span>
        <span id="lblNaslov">RS II - Rok</span>
        <span id="lblDatum" class="meta">16.10.2026 22:14 -</span>
        <span id="lblPredmet" class="meta">Razvoj softvera II</span>
        <a id="linkNapisao" class="meta" href="mailto:prof@edu.fit.ba">Prof</a>
        <div id="Panel1"><p>Prvi red<br/>Drugi red</p>
          <a href="https://teams.microsoft.com/x">Teams</a></div>
      ''');

      final detail = NotificationService.parseDetail(page);
      expect(detail.title, 'RS II - Rok');
      expect(detail.subject, 'Razvoj softvera II');
      expect(detail.author, 'Prof');
      expect(detail.authorEmail, 'prof@edu.fit.ba');
      expect(detail.body, startsWith('Prvi red\nDrugi red'));
      expect(detail.links.single.$1, 'Teams');
      expect(detail.dateTime, DateTime(2026, 10, 16, 22, 14));
    });
  });

  group('DocumentService', () {
    test('parses documents, filters and pager', () {
      final page =
          _reference('Dokumenti', 'nastava/dokumenti/pretraga.aspx');
      final data = DocumentService.parseDokumentiPage(page);

      expect(data.documents, isNotEmpty);
      final first = data.documents.first;
      expect(first.title, 'ADS - V1 - UML - 2025/2026');
      expect(first.type, 'Vježbe');
      expect(first.author, 'Emina Junuz');
      expect(first.sizeKb, 399);
      expect(first.date, DateTime(2026, 4, 7));
      expect(first.schoolYear, '2025/2026');
      expect(first.postBackTarget, contains('lbtnNaslov'));

      expect(data.subjectOptions.firstWhere((o) => o.isSelected).value, '146');
      expect(data.typeOptions.map((o) => o.label), contains('Predavanja'));

      expect(data.currentPage, 1);
      expect(data.totalPages, 3);
      expect(data.previousPageTarget, isNull);
      expect(data.nextPageTarget,
          r'ctl00$ContentPlaceHolder1$gridDokumenti$ctl01$ctl01');
    });
  });

  group('NastavaService', () {
    test('parses subject announcements and materials', () {
      final page = _reference('Nastava', 'nastava/index.aspx');
      final data = NastavaService.parseNastavaPage(page);

      expect(data.subjectOptions.firstWhere((o) => o.isSelected).label,
          'Analiza i dizajn softvera');
      expect(data.notifications.length, 5);
      expect(data.notifications.first.subject, 'Analiza i dizajn softvera');
      expect(data.notifications.first.content, contains('InClass'));
      expect(data.materials.length, 5);
      expect(data.materials.first.postBackTarget, contains('linkNaslov'));
    });
  });

  group('PrisustvoService', () {
    const list = '''
      <select name="ctl00\$ContentPlaceHolder1\$listGodine" id="listGodine">
        <option value="1">1</option><option selected="selected" value="3">3</option>
      </select>
      <table id="dgPrisustvo">
        <tr><td><a id="btnPredmet" href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgPrisustvo\$ctl02\$btnPredmet','')">Predmet A</a></td>
            <td><div class="bar"><img id="imgSlika" style="width:20%;"/></div></td>
            <td><span id="lblPostotak">20%</span></td></tr>
        <tr><td><a id="btnPredmet" href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgPrisustvo\$ctl03\$btnPredmet','')">Predmet B</a></td>
            <td></td><td><span id="lblPostotak">100%</span></td></tr>
      </table>''';

    test('parses subjects with percentages', () {
      final data = PrisustvoService.parsePrisustvoPage(
          _html('nastava/prisustvo.aspx', list));

      expect(data.subjects.length, 2);
      expect(data.subjects[0].name, 'Predmet A');
      expect(data.subjects[0].percentage, 20);
      expect(data.subjects[1].percentage, 100);
      expect(data.subjects[0].postBackTarget,
          r'ctl00$ContentPlaceHolder1$dgPrisustvo$ctl02$btnPredmet');
      expect(data.detail, isNull);
      expect(data.yearOptions.firstWhere((o) => o.isSelected).value, '3');
    });

    test('parses the per-subject breakdown', () {
      final data = PrisustvoService.parsePrisustvoPage(_html(
        'nastava/prisustvo.aspx',
        '''$list
        <div id="pnlDetalji"><span id="lblPredmet">Predmet B</span>
          <table id="dgPrisustvoPredmet">
            <tr><td><span id="lblNastava">Predavanja</span>
              <span id="lblBrojSati">(2/2)</span>
              <table><tr><td></td><td><span id="lblPostotak">100%</span></td></tr></table>
            </td></tr>
            <tr><td><span id="lblNastava">Vježbe</span>
              <span id="lblBrojSati">(1/4)</span>
              <table><tr><td></td><td><span id="lblPostotak">25%</span></td></tr></table>
            </td></tr>
          </table></div>''',
      ));

      final detail = data.detail!;
      expect(detail.subject, 'Predmet B');
      expect(detail.items.length, 2);
      expect(detail.items[1].kind, 'Vježbe');
      expect(detail.items[1].attended, 1);
      expect(detail.items[1].total, 4);
      expect(detail.items[1].percentage, 25);
      // Detail rows must not leak into the subject list.
      expect(data.subjects.length, 2);
    });
  });

  group('UspjehService', () {
    test('parses study info, passed and pending exams', () {
      final data = UspjehService.parseUspjehPage(_html(
        'evaluacija/uspjeh.aspx',
        '''
        <span id="lblStatus">Aktivan</span><span id="lblGodina">3</span>
        <span id="lblProsjecnaOcjena">8.50</span>
        <div id="TabPanel1"><table id="listPolozeni"><tr><td>
          <table id="gridPolozeni">
            <tr class="Header"><td class="Header">1. godina - predmet</td><td>Ocjena</td><td>Opisna ocjena</td><td>Datum polaganja</td><td>&nbsp;</td></tr>
            <tr class="grid"><td>Predmet X</td><td>9</td><td>devet</td><td>29.01.2025</td><td><a id="lbtnDetalji">Detalji</a></td></tr>
            <tr class="grid"><td>Predmet Y*</td><td>10</td><td>&nbsp;</td><td>20.01.2025</td><td></td></tr>
          </table></td></tr><tr><td>
          <table id="gridPolozeni">
            <tr class="Header"><td class="Header">2. godina - predmet</td><td></td><td></td><td></td><td></td></tr>
            <tr class="grid"><td>Predmet Z</td><td>6</td><td>šest</td><td>06.07.2026</td><td></td></tr>
          </table></td></tr></table></div>
        <div id="TabPanel2"><table id="listNepolozeni"><tr><td>
          <table id="gridNepolozeni">
            <tr class="Header"><td class="Header">3. godina - predmet</td><td>Uslov</td><td>Datum uslova</td><td>Broj izlazaka</td><td></td></tr>
            <tr class="grid"><td>Predmet P</td><td><span class="aspNetDisabled"><input type="checkbox" name="c1" disabled="disabled" /></span></td><td>&nbsp;</td><td>&nbsp;</td><td></td></tr>
            <tr class="grid"><td>Predmet Q</td><td><input type="checkbox" name="c2" checked="checked" disabled="disabled" /></td><td>10.06.2026</td><td>2</td><td></td></tr>
          </table></td></tr></table></div>
        ''',
      ));

      expect(data.info.status, 'Aktivan');
      expect(data.info.yearOfStudy, '3');
      expect(data.info.averageGrade, '8.50');

      expect(data.passed.length, 2);
      expect(data.passed[0].title, '1. godina');
      expect(data.passed[0].exams.length, 2);
      expect(data.passed[0].exams[0].grade, 9);
      expect(data.passed[0].exams[0].date, DateTime(2025, 1, 29));
      expect(data.passed[0].exams[1].gradeDescription, '');
      expect(data.passed[1].exams.single.subject, 'Predmet Z');
      expect(data.passedCount, 3);

      expect(data.pending.single.title, '3. godina');
      expect(data.pending.single.exams[0].requirementMet, isFalse);
      expect(data.pending.single.exams[1].requirementMet, isTrue);
      expect(data.pending.single.exams[1].attempts, 2);
    });
  });

  group('ObavijestiWatcher', () {
    DlwmsNotification n(String id) => DlwmsNotification(
          id: id,
          title: id,
          content: '',
          dateTime: DateTime(2026),
          subject: '',
          author: '',
          authorEmail: '',
        );

    test('first run records a baseline without alerting', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await ObavijestiWatcher.detectNew([n('a'), n('b')], prefs),
          isEmpty);
      expect(prefs.getStringList(ObavijestiWatcher.seenKey), ['a', 'b']);
    });

    test('reports only unseen items, once', () async {
      SharedPreferences.setMockInitialValues({
        ObavijestiWatcher.seenKey: ['a', 'b'],
      });
      final prefs = await SharedPreferences.getInstance();

      final fresh =
          await ObavijestiWatcher.detectNew([n('c'), n('a'), n('b')], prefs);
      expect(fresh.map((x) => x.id), ['c']);

      expect(await ObavijestiWatcher.detectNew([n('c'), n('a')], prefs),
          isEmpty);
    });

    test('an empty (failed) fetch does not reset the baseline', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(await ObavijestiWatcher.detectNew([], prefs), isEmpty);
      expect(prefs.getStringList(ObavijestiWatcher.seenKey), isNull);
    });
  });
}
