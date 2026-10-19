import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';

/// Search criteria for the announcement archive (`obavijesti/arhiva.aspx`).
class ArhivaQuery {
  const ArhivaQuery({
    this.words = '',
    this.subject = '',
    this.anyWord = false,
    this.from,
    this.to,
  });

  /// Words that must appear in the title.
  final String words;

  /// Subject id from the dropdown; empty means all subjects.
  final String subject;

  /// Match any of the words (OR) instead of all of them (AND).
  final bool anyWord;
  final DateTime? from;
  final DateTime? to;

  bool get isEmpty =>
      words.trim().isEmpty && subject.isEmpty && from == null && to == null;

  ArhivaQuery copyWith({
    String? words,
    String? subject,
    bool? anyWord,
    DateTime? from,
    DateTime? to,
    bool clearDates = false,
  }) {
    return ArhivaQuery(
      words: words ?? this.words,
      subject: subject ?? this.subject,
      anyWord: anyWord ?? this.anyWord,
      from: clearDates ? null : (from ?? this.from),
      to: clearDates ? null : (to ?? this.to),
    );
  }

  static const _prefix = r'ctl00$ContentPlaceHolder1$';

  /// Form fields DLWMS expects when "Traži" is pressed.
  Map<String, String> toFields() {
    final format = DateFormat('dd.MM.yyyy');
    return {
      '${_prefix}listPredmet': subject,
      '${_prefix}txtRijeci': words.trim(),
      '${_prefix}listOperator': anyWord ? 'OR' : 'AND',
      '${_prefix}txtDatumOd': from == null ? '' : format.format(from!),
      '${_prefix}txtDatumDo': to == null ? '' : format.format(to!),
      '${_prefix}btnTrazi': 'Traži',
    };
  }
}

class ArhivaPageData {
  const ArhivaPageData({
    required this.subjects,
    required this.results,
    required this.pager,
  });

  final List<DlwmsFilterOption> subjects;
  final List<DlwmsNotification> results;
  final List<DlwmsPagerLink> pager;

  /// Postback target of the next page of results, if any.
  String? get nextPage => nextPageTarget(pager);
}

class ArhivaService {
  static ArhivaPageData parse(DlwmsPage page, {String subjectName = ''}) {
    final document = page.document;
    final table = document.querySelector('#dgArhiva');

    final results = <DlwmsNotification>[];
    for (final row in table?.querySelectorAll('tr.grid') ?? const <dom.Element>[]) {
      final cells =
          row.children.where((cell) => cell.localName == 'td').toList();
      if (cells.length < 2) continue;

      final link = cells[1].querySelector('a');
      final title = link?.text.trim() ?? '';
      if (title.isEmpty) continue;

      final dateText = cells[0].text.trim();
      final href = link?.attributes['href'];

      results.add(
        DlwmsNotification(
          id: '$dateText|$title',
          title: title,
          content: '',
          dateTime: parseDlwmsDate(dateText) ?? DateTime.now(),
          subject: subjectName,
          author: '',
          authorEmail: '',
          url: href == null ? null : page.resolve(href).toString(),
        ),
      );
    }

    return ArhivaPageData(
      subjects: parseSelectOptions(document, '#listPredmet'),
      results: results,
      pager: parseGridPager(table, 'dgArhiva'),
    );
  }
}
