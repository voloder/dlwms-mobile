import 'package:dlwms_mobile/models/ispit.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:html/dom.dart' as dom;

/// Parsers for exam terms (`rokovi/index.aspx`), tests
/// (`EUSASStudentHome.aspx`) and the "Zadnji dokumenti" sidebar.
class IspitiService {
  static const String periodField = r'ctl00$ContentPlaceHolder1$listRokovi';

  static ExamTermsPageData parseTerms(DlwmsPage page) {
    final document = page.document;
    final periods = parseSelectOptions(document, '#listRokovi');
    final periodId = selectedOption(periods)?.value ?? '';

    final terms = <ExamTerm>[];
    final grid = document.querySelector('#gridTermini');
    for (final row in grid?.querySelectorAll('tr') ?? const <dom.Element>[]) {
      if (row.classes.contains('Header')) continue;
      final cells =
          row.children.where((cell) => cell.localName == 'td').toList();
      if (cells.length < 3) continue;

      final subject = _clean(cells[0].text);
      if (subject.isEmpty || subject == 'Naslov') continue;

      final dateText = _clean(cells[1].text);
      final timeText = _clean(cells[2].text);
      final checkbox = row.querySelector('input[type="checkbox"]');

      terms.add(
        ExamTerm(
          subject: subject,
          dateText: dateText,
          timeText: timeText,
          dateTime: parseDlwmsDate('$dateText $timeText'),
          seats: cells.length > 3 ? _clean(cells[3].text) : '',
          registered: checkbox?.attributes.containsKey('checked') ?? false,
          selectable: checkbox != null &&
              !checkbox.attributes.containsKey('disabled'),
          periodId: periodId,
        ),
      );
    }

    terms.sort((a, b) {
      final at = a.dateTime, bt = b.dateTime;
      if (at == null || bt == null) return 0;
      return at.compareTo(bt);
    });

    return ExamTermsPageData(periods: periods, terms: terms);
  }

  static TestsPageData parseTests(DlwmsPage page) {
    final document = page.document;

    final active = <ActiveTest>[];
    for (final cells in _rows(document.querySelector(
        '#gvIndexCurrentlyActiveTests'))) {
      if (cells.length < 5 || cells[0].isEmpty) continue;
      active.add(
        ActiveTest(
          subject: cells[0],
          name: cells[1],
          durationMinutes: int.tryParse(cells[2]),
          from: parseDlwmsDate(cells[3]),
          to: parseDlwmsDate(cells[4]),
        ),
      );
    }
    // DLWMS keeps the table but hides its block when nothing is active.
    final activeBlock = document.querySelector('#currentActiveTestsBlock');
    if (activeBlock != null &&
        (activeBlock.attributes['style'] ?? '').contains('display:none')) {
      active.clear();
    }

    final results = <TestResult>[];
    for (final cells
        in _rows(document.querySelector('#gvIndexPreviousTests'))) {
      if (cells.length < 4 || cells[0].isEmpty) continue;
      results.add(
        TestResult(
          subject: cells[0],
          name: cells[1],
          dateText: cells[2],
          dateTime: parseDlwmsDate(cells[2]),
          percentage: double.tryParse(cells[3].replaceAll(',', '.')),
        ),
      );
    }

    return TestsPageData(active: active, results: results);
  }

  /// Newest documents listed in the sidebar of every DLWMS page.
  static List<SidebarDocument> parseSidebarDocuments(DlwmsPage page) {
    final grid = page.document.querySelector('#gridMaterijali');
    if (grid == null) return const [];

    final documents = <SidebarDocument>[];
    for (final link in grid.querySelectorAll('a#lbtnNaslov')) {
      final title = (link.attributes['title'] ?? link.text).trim();
      if (title.isEmpty) continue;

      var container = link.parent;
      while (container != null && container.localName != 'td') {
        container = container.parent;
      }
      final subject = container == null
          ? ''
          : textOf(container, 'span#lblPredmetNaziv');

      documents.add(SidebarDocument(title: title, subject: subject));
    }
    return documents;
  }

  /// Data rows of a GridView as trimmed cell texts (header and pager rows
  /// are skipped because they use `th` or a single spanning cell).
  static Iterable<List<String>> _rows(dom.Element? table) sync* {
    if (table == null) return;
    for (final row in table.querySelectorAll('tr')) {
      if (row.parent?.parent != table && row.parent != table) continue;
      final cells =
          row.children.where((cell) => cell.localName == 'td').toList();
      if (cells.length < 2) continue;
      yield cells.map((cell) => _clean(cell.text)).toList();
    }
  }

  static String _clean(String text) =>
      text.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
