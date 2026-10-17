import 'package:dlwms_mobile/models/prisustvo.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:html/dom.dart' as dom;

class PrisustvoService {
  /// Parses `nastava/prisustvo.aspx` (and the same page after a subject was
  /// clicked, which adds the `#pnlDetalji` breakdown).
  static PrisustvoPageData parsePrisustvoPage(DlwmsPage page) {
    final document = page.document;

    final subjects = <PrisustvoSubject>[];
    final table = document.querySelector('#dgPrisustvo');
    for (final link in table?.querySelectorAll('a#btnPredmet') ?? const []) {
      final row = _closest(link, 'tr');
      subjects.add(
        PrisustvoSubject(
          name: link.text.trim(),
          percentage:
              _percent(row == null ? '' : textOf(row, 'span#lblPostotak')),
          postBackTarget: postBackTarget(link.attributes['href']),
        ),
      );
    }

    return PrisustvoPageData(
      yearOptions: parseSelectOptions(document, '#listGodine'),
      subjects: subjects,
      detail: _parseDetail(document),
    );
  }

  static PrisustvoDetail? _parseDetail(dom.Document document) {
    final panel = document.querySelector('#pnlDetalji');
    if (panel == null) return null;

    final items = <PrisustvoDetailItem>[];
    for (final label in panel.querySelectorAll('span#lblNastava')) {
      final cell = _closest(label, 'td') ?? label.parent!;
      final hours = RegExp(r'(\d+)\s*/\s*(\d+)')
          .firstMatch(textOf(cell, 'span#lblBrojSati'));

      items.add(
        PrisustvoDetailItem(
          kind: label.text.trim(),
          percentage: _percent(textOf(cell, 'span#lblPostotak')),
          attended: hours == null ? null : int.parse(hours.group(1)!),
          total: hours == null ? null : int.parse(hours.group(2)!),
        ),
      );
    }

    return PrisustvoDetail(
      subject: textOf(panel, '#lblPredmet'),
      items: items,
    );
  }

  static int _percent(String raw) {
    final match = RegExp(r'(\d+)').firstMatch(raw);
    final value = match == null ? 0 : int.parse(match.group(1)!);
    return value.clamp(0, 100).toInt();
  }

  static dom.Element? _closest(dom.Element element, String tag) {
    dom.Element? current = element.parent;
    while (current != null && current.localName != tag) {
      current = current.parent;
    }
    return current;
  }
}
