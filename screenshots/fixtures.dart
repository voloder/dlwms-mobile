import 'dart:io';

/// Saved DLWMS page from the repository's `references/` folder.
String readReference(String name) =>
    File('references/DLWMS - $name.htm').readAsStringSync();

const loginPage = '''
<html><body><form method="post" action="./login.aspx">
<input type="hidden" name="__VIEWSTATE" value="x" />
<input type="hidden" name="__EVENTVALIDATION" value="y" />
<input name="txtBrojDosijea" type="text" />
<input name="txtLozinka" type="password" />
<select name="listInstitucija"><option selected="selected" value="1">FIT</option></select>
<input type="submit" name="btnPrijava" value="Prijava" />
</form></body></html>
''';

String _row(int index, String subject, int percentage) => '''
<tr><td style="width:60%;"><a id="btnPredmet" href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgPrisustvo\$ctl${index.toString().padLeft(2, '0')}\$btnPredmet','')">$subject</a></td>
<td><div class="bar"><img id="imgSlika" style="width:$percentage%;" /></div></td>
<td><span id="lblPostotak">$percentage%</span></td></tr>''';

/// Made-up attendance (no real student data).
final prisustvoPage = '''
<html><body><form method="post" action="./prisustvo.aspx">
<input type="hidden" name="__VIEWSTATE" value="x" />
<select name="ctl00\$ContentPlaceHolder1\$listGodine" id="listGodine">
<option value="1">1</option><option value="2">2</option>
<option selected="selected" value="3">3</option></select>
<table id="dgPrisustvo">
${[
  ('Administracija baza podataka', 92),
  ('Dizajn i razvoj IOT projekata', 80),
  ('Informacijska sigurnost', 64),
  ('Interakcija čovjek-računar', 100),
  ('Kvalitet softvera', 45),
  ('Modeliranje poslovnih procesa', 100),
  ('Poslovna inteligencija', 0),
  ('Razvoj softvera II', 75),
].indexed.map((e) => _row(e.$1 + 2, e.$2.$1, e.$2.$2)).join()}
</table></form></body></html>
''';

String _passed(String subject, int grade, String word, String date) =>
    '<tr class="grid"><td>$subject</td><td align="center">$grade</td>'
    '<td align="center">$word</td><td align="center">$date</td><td></td></tr>';

String _pending(int i, String subject, bool met, String date, String tries) =>
    '<tr class="grid" valign="top"><td>$subject</td><td align="center">'
    '<input type="checkbox" name="c$i" disabled="disabled"${met ? ' checked="checked"' : ''} /></td>'
    '<td align="center">$date</td><td align="center">$tries</td><td></td></tr>';

/// Made-up grades (no real student data).
final uspjehPage = '''
<html><body><form method="post" action="./uspjeh.aspx">
<span id="lblStatus">Aktivan</span>
<span id="lblGodinaUpisa">2024/2025</span>
<span id="lblGodina">3</span>
<span id="lblObnova">Ne</span>
<span id="lblNacinStudiranja">Redovan</span>
<span id="lblUpisaniSemestar">5</span>
<span id="lblUpisanaSkolskaGodina">2026/2027</span>
<span id="lblOvjereniSemestar">4</span>
<span id="lblOvjerenaSkolskaGodina">2025/2026</span>
<span id="lblProsjecnaOcjena">8.62</span>
<div id="TabPanel1"><table id="listPolozeni"><tr><td>
<table id="gridPolozeni">
<tr class="Header"><td class="Header">1. godina - predmet</td><td>Ocjena</td><td>Opisna ocjena</td><td>Datum polaganja</td><td></td></tr>
${_passed('Programiranje I', 10, 'deset', '01.02.2025')}
${_passed('Matematika I', 8, 'osam', '14.02.2025')}
${_passed('Digitalna logika', 9, 'devet', '29.01.2025')}
${_passed('Operativni sistemi', 7, 'sedam', '19.06.2025')}
${_passed('Web razvoj i dizajn', 10, 'deset', '21.06.2025')}
</table></td></tr><tr><td>
<table id="gridPolozeni">
<tr class="Header"><td class="Header">2. godina - predmet</td><td></td><td></td><td></td><td></td></tr>
${_passed('Baze podataka I', 8, 'osam', '17.02.2026')}
${_passed('Programiranje III', 9, 'devet', '14.02.2026')}
${_passed('Strukture podataka i algoritmi', 10, 'deset', '22.01.2026')}
${_passed('Računarske mreže I', 6, 'šest', '19.01.2026')}
</table></td></tr></table></div>
<div id="TabPanel2"><table id="listNepolozeni"><tr><td>
<table id="gridNepolozeni">
<tr class="Header"><td class="Header">3. godina - predmet</td><td>Uslov</td><td>Datum uslova</td><td>Broj izlazaka</td><td></td></tr>
${_pending(1, 'Administracija baza podataka', true, '15.01.2027', '0')}
${_pending(2, 'Informacijska sigurnost', false, '', '')}
${_pending(3, 'Kvalitet softvera', false, '', '')}
${_pending(4, 'Razvoj softvera II', true, '20.01.2027', '1')}
</table></td></tr></table></div>
</form></body></html>
''';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _termRow(int i, String subject, DateTime day, String time,
        {bool registered = false}) =>
    '<tr class="grid" valign="top"><td style="width:400px;">'
    '<span id="lblPredmetNaziv">$subject </span></td>'
    '<td>${_date(day)}</td><td>$time</td><td align="center">&nbsp;</td>'
    '<td><input id="chkSelect" type="checkbox" '
    'name="ctl00\$ContentPlaceHolder1\$gridTermini\$ctl${i.toString().padLeft(2, '0')}\$chkSelect"'
    '${registered ? ' checked="checked"' : ''} /></td></tr>';

/// Exam terms relative to today, in the structure of `rokovi/index.aspx`.
/// [selected] is the exam period DLWMS shows (its default is the
/// apsolventski one, which the app hides unless turned on).
String rokoviPage([String selected = '760']) {
  final now = DateTime.now();
  DateTime day(int offset) => DateTime(now.year, now.month, now.day + offset);

  const periods = {
    '760': 'Apsolventski ispitni rokovi za oktobar 2026/27.',
    '770': 'Zimski ispitni rok 2026/27.',
    '751': 'Septembarski ispitni rok 2025/26.',
  };

  final rows = switch (selected) {
    '770' => [
        _termRow(2, 'Administracija baza podataka', day(1), '09:00',
            registered: true),
        _termRow(3, 'Kvalitet softvera', day(3), '12:00'),
        _termRow(4, 'Interakcija čovjek-računar', day(6), '10:00'),
        _termRow(5, 'Informacijska sigurnost', day(8), '13:00'),
        _termRow(6, 'Razvoj softvera II', day(10), '11:00'),
        _termRow(7, 'Poslovna inteligencija', day(13), '09:00'),
      ],
    '751' => [
        _termRow(2, 'Razvoj softvera I', day(-30), '11:00'),
        _termRow(3, 'Baze podataka II', day(-27), '09:00'),
      ],
    _ => [
        _termRow(2, 'Razvoj softvera I', day(-1), '11:00'),
        _termRow(3, 'Modeliranje poslovnih procesa', day(1), '13:00'),
        _termRow(4, 'Upravljanje projektom', day(4), '11:00'),
      ],
  };

  final options = periods.entries
      .map((e) => '<option ${e.key == selected ? 'selected="selected" ' : ''}'
          'value="${e.key}">${e.value}</option>')
      .join();

  return '''
<html><body><form method="post" action="./index.aspx">
<input type="hidden" name="__VIEWSTATE" value="x" />
<select name="ctl00\$ContentPlaceHolder1\$listRokovi" id="listRokovi">$options</select>
<table cellspacing="5" cellpadding="2" id="gridTermini" style="width:100%;">
<tr class="Header"><td>Naslov</td><td>Datum</td><td>Vrijeme</td><td>Zauzeto mjesta</td><td>&nbsp;</td></tr>
${rows.join('\n')}
</table>
<input type="submit" name="ctl00\$ContentPlaceHolder1\$bntPrijava" value="Prijavi odabrane ispite" />
</form></body></html>
''';
}

String _dateTime(DateTime d) =>
    '${d.day}.${d.month}.${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}:00';

/// Made-up tests in the structure of `EUSASStudentHome.aspx`.
String testsPage() {
  final now = DateTime.now();
  final from = now.subtract(const Duration(minutes: 40));
  final to = DateTime(now.year, now.month, now.day, now.hour + 3, 30);
  return '''
<html><body><form method="post" action="./EUSASStudentHome.aspx">
<div id="currentActiveTestsBlock" style="display:block;">
<table id="gvIndexCurrentlyActiveTests">
<tr><th>Predmet</th><th>Naziv</th><th>Trajanje</th><th>Od</th><th>Do</th><th>&nbsp;</th></tr>
<tr><td>Razvoj softvera I</td><td>RSI :: kolokvij</td><td>20</td><td>${_dateTime(from)}</td><td>${_dateTime(to)}</td><td></td></tr>
</table></div>
<div id="previousTestsBlock" style="display:block;">
<table id="gvIndexPreviousTests">
<tr><th>Predmet</th><th>Naziv</th><th>Datum</th><th>Uspjeh (%)</th><th>&nbsp;</th></tr>
<tr><td>Engleski jezik III</td><td>Drugi parcijalni ispit</td><td>23.6.2026 13:32:27</td><td>88.64</td><td></td></tr>
<tr><td>Kompjuterska grafika</td><td>Parcijalni ispit</td><td>13.4.2026 10:04:56</td><td>71.5</td><td></td></tr>
</table></div>
</form></body></html>
''';
}

const arhivaForm = '''
<html><body><form method="post" action="./arhiva.aspx">
<input type="hidden" name="__VIEWSTATE" value="x" />
<select name="ctl00\$ContentPlaceHolder1\$listPredmet" id="listPredmet">
<option selected="selected" value=""></option>
<option value="157">Razvoj softvera II</option>
<option value="150">Razvoj softvera I</option>
<option value="232">Kvalitet softvera</option>
</select>
<input name="ctl00\$ContentPlaceHolder1\$txtRijeci" type="text" id="txtRijeci" />
<select name="ctl00\$ContentPlaceHolder1\$listOperator" id="listOperator">
<option selected="selected" value="AND">Sve riječi (AND)</option>
<option value="OR">Bilo koja riječ (OR)</option></select>
<input name="ctl00\$ContentPlaceHolder1\$txtDatumOd" type="text" id="txtDatumOd" />
<input name="ctl00\$ContentPlaceHolder1\$txtDatumDo" type="text" id="txtDatumDo" />
<input type="submit" name="ctl00\$ContentPlaceHolder1\$btnTrazi" value="Traži" />
</form></body></html>
''';

String _archiveRow(String date, String title) =>
    '<tr class="grid" valign="top"><td style="width:120px;">$date</td>'
    '<td style="width:370px;"><a id="lnkNaslov" href="opsirnije.aspx?sqs=${Uri.encodeComponent(title)}">$title</a></td></tr>';

final arhivaResults = arhivaForm.replaceFirst('</form>', '''
<table cellspacing="0" id="dgArhiva">
${_archiveRow('18.10.2026 22:12', 'RSI :: Apsolventski ispitni termin :: 19.10.2026')}
${_archiveRow('12.10.2026 15:32', 'Raspored apsolventskih ispitnih rokova za oktobar ak. 2026/27.')}
${_archiveRow('09.10.2026 14:18', 'BPI :: Obavijest o priznavanju teorijskog dijela ispita')}
${_archiveRow('30.09.2026 12:49', 'PRIII :: Rezultati ispita :: 16.09.2026')}
${_archiveRow('28.09.2026 11:50', 'RSII :: Rezultati ispita :: 15.09.2026')}
${_archiveRow('18.09.2026 13:48', 'BPI :: Konačne ocjene za ispitni termin 11.09.2026')}
<tr class="pgr" align="right"><td colspan="2"><span>1</span>&nbsp;<a href="javascript:__doPostBack('ctl00\$ContentPlaceHolder1\$dgArhiva\$ctl24\$ctl01','')">2</a></td></tr>
</table></form>''');
