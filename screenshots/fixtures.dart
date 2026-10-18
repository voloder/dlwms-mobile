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
