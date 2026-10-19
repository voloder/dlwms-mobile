import 'package:html/dom.dart' as dom;

import '../models/document.dart';

final RegExp _postBackPattern = RegExp(r"__doPostBack\('([^']+)'");

/// Extracts the event target from a `javascript:__doPostBack('target','')`
/// link or onchange handler.
String? postBackTarget(String? href) {
  if (href == null) return null;
  return _postBackPattern.firstMatch(href)?.group(1);
}

/// Converts an element's content to readable plain text, keeping line breaks
/// from `<br>`, paragraphs and block elements.
String htmlToText(dom.Element? element) {
  if (element == null) return '';

  final buffer = StringBuffer();
  const blockTags = {'p', 'div', 'li', 'tr', 'h1', 'h2', 'h3', 'h4', 'ul', 'ol'};

  void walk(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text.replaceAll(RegExp(r'\s+'), ' '));
      return;
    }
    if (node is! dom.Element) return;

    final tag = node.localName;
    if (tag == 'script' || tag == 'style') return;
    if (tag == 'br') {
      buffer.write('\n');
      return;
    }

    final isBlock = blockTags.contains(tag);
    if (isBlock) buffer.write('\n');
    if (tag == 'li') buffer.write('• ');
    for (final child in node.nodes) {
      walk(child);
    }
    if (isBlock) buffer.write('\n');
  }

  walk(element);

  return buffer
      .toString()
      .replaceAll(' ', ' ')
      .split('\n')
      .map((line) => line.trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

/// Trimmed text of the first element matching [selector] under [root].
String textOf(dom.Element root, String selector) =>
    (root.querySelector(selector)?.text ?? '')
        .replaceAll(' ', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

/// Reads the options of a `<select>` identified by [selector].
List<DlwmsFilterOption> parseSelectOptions(
    dom.Document document, String selector) {
  final select = document.querySelector(selector);
  if (select == null) return const [];

  return select
      .querySelectorAll('option')
      .map(
        (option) => DlwmsFilterOption(
          label: option.text.trim(),
          value: option.attributes['value'] ?? option.text.trim(),
          isSelected: option.attributes.containsKey('selected'),
        ),
      )
      .toList(growable: false);
}

/// The selected option of a dropdown, or the first option if none is marked.
DlwmsFilterOption? selectedOption(List<DlwmsFilterOption> options) {
  if (options.isEmpty) return null;
  return options.firstWhere(
    (option) => option.isSelected,
    orElse: () => options.first,
  );
}

/// Parses `dd.MM.yyyy HH:mm` or `dd.MM.yyyy`, ignoring trailing dashes.
DateTime? parseDlwmsDate(String raw) {
  final match = RegExp(
    r'(\d{1,2})\.(\d{1,2})\.(\d{4})(?:\.)?(?:\s+(\d{1,2}):(\d{2}))?',
  ).firstMatch(raw);
  if (match == null) return null;

  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;

  if (month < 1 || month > 12 || day < 1 || day > 31 || hour > 23) {
    return null;
  }
  return DateTime(year, month, day, hour, minute);
}

/// Maps the DLWMS mime icon (e.g. `file_pdf.png`, `box_rar.png`) to a type.
String fileTypeFromIcon(String? iconSrc) {
  final icon = (iconSrc ?? '').toLowerCase();
  if (icon.contains('pdf')) return 'pdf';
  if (icon.contains('rar') || icon.contains('zip') || icon.contains('box')) {
    return 'archive';
  }
  if (icon.contains('doc')) return 'doc';
  if (icon.contains('xls')) return 'sheet';
  if (icon.contains('ppt')) return 'slides';
  if (icon.contains('jpg') || icon.contains('png') || icon.contains('img')) {
    return 'image';
  }
  return 'file';
}

final RegExp _pagerLabel = RegExp(r'^(\d+|\.\.\.)$');

/// Reads an ASP.NET grid pager ("1 2 3 … 10 …") inside [table]. Only links
/// whose postback target mentions [gridId] are used, so links inside the
/// grid's rows are ignored. Returns an empty list for a single page.
List<DlwmsPagerLink> parseGridPager(dom.Element? table, String gridId) {
  if (table == null) return const [];

  for (final row in table.querySelectorAll('tr').reversed) {
    final links = <DlwmsPagerLink>[];
    var hasPageLink = false;

    for (final element in row.querySelectorAll('span, a')) {
      final label = element.text.trim();
      if (!_pagerLabel.hasMatch(label)) continue;

      if (element.localName == 'span') {
        links.add(DlwmsPagerLink(label: label));
      } else {
        final target = postBackTarget(element.attributes['href']);
        if (target != null && target.contains(gridId)) {
          links.add(DlwmsPagerLink(label: label, target: target));
          hasPageLink = true;
        }
      }
    }

    if (hasPageLink && links.any((link) => link.isCurrent)) return links;
  }
  return const [];
}

/// Target of the pager link right after the current page, if any.
String? nextPageTarget(List<DlwmsPagerLink> links) {
  final index = links.indexWhere((link) => link.isCurrent);
  if (index < 0 || index + 1 >= links.length) return null;
  return links[index + 1].target;
}
