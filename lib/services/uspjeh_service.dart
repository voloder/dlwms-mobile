import 'package:dlwms_mobile/models/uspjeh.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:html/dom.dart' as dom;

class UspjehService {
  /// Parses `evaluacija/uspjeh.aspx`: study info, passed exams per year and
  /// exams that are still open.
  static UspjehPageData parseUspjehPage(DlwmsPage page) {
    final document = page.document;
    final root = document.documentElement!;

    String label(String id) => textOf(root, '#$id');

    final info = StudyInfo(
      status: label('lblStatus'),
      enrollmentYear: label('lblGodinaUpisa'),
      yearOfStudy: label('lblGodina'),
      repeatingYear: label('lblObnova'),
      studyMode: label('lblNacinStudiranja'),
      enrolledSemester: label('lblUpisaniSemestar'),
      enrolledSchoolYear: label('lblUpisanaSkolskaGodina'),
      verifiedSemester: label('lblOvjereniSemestar'),
      verifiedSchoolYear: label('lblOvjerenaSkolskaGodina'),
      averageGrade: label('lblProsjecnaOcjena'),
    );

    final passed = <ExamGroup<PassedExam>>[];
    for (final grid in _tablesWithId(document, 'gridPolozeni')) {
      final exams = <PassedExam>[];
      for (final row in _rows(grid, 'grid')) {
        final cells = _cells(row);
        if (cells.length < 4 || cells[0].isEmpty) continue;
        exams.add(
          PassedExam(
            subject: cells[0],
            grade: int.tryParse(cells[1]),
            gradeDescription: cells[2],
            date: parseDlwmsDate(cells[3]),
          ),
        );
      }
      if (exams.isNotEmpty) {
        passed.add(ExamGroup(title: _groupTitle(grid), exams: exams));
      }
    }

    final pending = <ExamGroup<PendingExam>>[];
    for (final grid in _tablesWithId(document, 'gridNepolozeni')) {
      final exams = <PendingExam>[];
      for (final row in _rows(grid, 'grid')) {
        final cells = _cells(row);
        if (cells.length < 4 || cells[0].isEmpty) continue;
        final checkbox = row.querySelector('input[type="checkbox"]');
        exams.add(
          PendingExam(
            subject: cells[0],
            requirementMet: checkbox?.attributes.containsKey('checked') ?? false,
            requirementDate: cells[2],
            attempts: int.tryParse(cells[3]),
          ),
        );
      }
      if (exams.isNotEmpty) {
        pending.add(ExamGroup(title: _groupTitle(grid), exams: exams));
      }
    }

    return UspjehPageData(info: info, passed: passed, pending: pending);
  }

  static Iterable<dom.Element> _tablesWithId(dom.Document document, String id) =>
      document
          .querySelectorAll('table')
          .where((table) => table.attributes['id'] == id);

  /// Direct rows of [table] (not rows of nested tables) with [cssClass].
  static Iterable<dom.Element> _rows(dom.Element table, String cssClass) sync* {
    for (final section in table.children) {
      final rows = section.localName == 'tr' ? [section] : section.children;
      for (final row in rows) {
        if (row.localName == 'tr' && row.classes.contains(cssClass)) {
          yield row;
        }
      }
    }
  }

  static List<String> _cells(dom.Element row) => row.children
      .where((cell) => cell.localName == 'td')
      .map((cell) =>
          cell.text.replaceAll(' ', ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
      .toList();

  /// "1. godina - predmet" → "1. godina".
  static String _groupTitle(dom.Element table) {
    final header = _rows(table, 'Header').firstOrNull;
    final first = header == null ? '' : (_cells(header).firstOrNull ?? '');
    final title = first.split(' - ').first.trim();
    return title.isEmpty ? 'Predmeti' : title;
  }
}
