import 'document.dart';

/// One exam term from "Termini" (`rokovi/index.aspx`).
class ExamTerm {
  const ExamTerm({
    required this.subject,
    required this.dateTime,
    required this.dateText,
    required this.timeText,
    required this.seats,
    required this.registered,
    required this.selectable,
    required this.periodId,
  });

  final String subject;

  /// Null when DLWMS shows a date we can't parse.
  final DateTime? dateTime;
  final String dateText;
  final String timeText;

  /// "Zauzeto mjesta" as shown by DLWMS (often empty).
  final String seats;

  /// The registration checkbox is already ticked.
  final bool registered;

  /// The registration checkbox can still be changed.
  final bool selectable;

  final String periodId;

  /// Stable id used for reminders and "new term" detection.
  String get id => '$periodId|$subject|$dateText|$timeText';

  bool isPast([DateTime? now]) {
    final at = dateTime;
    if (at == null) return false;
    return at.isBefore(now ?? DateTime.now());
  }
}

class ExamTermsPageData {
  const ExamTermsPageData({required this.periods, required this.terms});

  /// Exam periods ("ispitni rokovi") offered in the dropdown.
  final List<DlwmsFilterOption> periods;
  final List<ExamTerm> terms;
}

/// A test that can be taken right now (Testovi → Trenutno aktivni testovi).
class ActiveTest {
  const ActiveTest({
    required this.subject,
    required this.name,
    required this.durationMinutes,
    this.from,
    this.to,
  });

  final String subject;
  final String name;
  final int? durationMinutes;
  final DateTime? from;
  final DateTime? to;

  String get id => '$subject|$name|${from?.toIso8601String() ?? ''}';
}

/// A finished test with its score (Testovi → Prethodni testovi).
class TestResult {
  const TestResult({
    required this.subject,
    required this.name,
    required this.dateText,
    required this.percentage,
    this.dateTime,
  });

  final String subject;
  final String name;
  final String dateText;
  final DateTime? dateTime;

  /// Score in percent, e.g. 62.16.
  final double? percentage;

  String get id => '$subject|$name|$dateText';
}

class TestsPageData {
  const TestsPageData({required this.active, required this.results});

  final List<ActiveTest> active;
  final List<TestResult> results;
}

/// A document from the "Zadnji dokumenti" sidebar shown on every page.
class SidebarDocument {
  const SidebarDocument({required this.title, required this.subject});

  final String title;

  /// Subject abbreviation as DLWMS shows it, e.g. "MPP".
  final String subject;

  String get id => '$subject|$title';
}
