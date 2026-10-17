import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;

class DocumentService {
  static DokumentiPageData parseDokumentiPage(DlwmsPage page) {
    final document = page.document;

    final documents = <DlwmsDocument>[];
    final rows = document.querySelectorAll('#gridDokumenti contenttemplate');
    for (final row in rows) {
      final parsed = _parseDocumentRow(row);
      if (parsed != null) documents.add(parsed);
    }

    final pagerLinks = _parsePager(document);
    final current = pagerLinks.where((l) => l.isCurrent).firstOrNull?.page ?? 1;
    final maxVisible = pagerLinks
        .map((l) => l.page ?? 0)
        .fold<int>(current, (max, page) => page > max ? page : max);

    return DokumentiPageData(
      documents: documents,
      yearOptions: parseSelectOptions(document, '#listGodina'),
      subjectOptions: parseSelectOptions(document, '#ddlPredmeti'),
      typeOptions: parseSelectOptions(document, '#listVrsta'),
      schoolYearOptions: parseSelectOptions(document, '#ddlSkolskeGodine'),
      keyword: document
              .querySelector('#txtKljucneRijeci')
              ?.attributes['value']
              ?.trim() ??
          '',
      currentPage: current,
      totalPages: maxVisible,
      pagerLinks: pagerLinks,
    );
  }

  static DlwmsDocument? _parseDocumentRow(dom.Element row) {
    try {
      final titleElement = row.querySelector('a#lbtnNaslov');
      final title = titleElement?.text.trim() ?? '';
      if (title.isEmpty) return null;

      final target = postBackTarget(titleElement?.attributes['href']);

      final fileType =
          fileTypeFromIcon(row.querySelector('img#imgType')?.attributes['src']);

      final meta = _parseMeta(textOf(row, 'span#lblVrsta'));

      final sizeKb = int.tryParse(textOf(row, 'span#lblDokumentSize')) ?? 0;

      final schoolYearMatch = RegExp(r'(\d{4}/\d{4})').firstMatch(title);

      return DlwmsDocument(
        id: target ?? title,
        title: title,
        type: meta.$1,
        author: meta.$3,
        fileType: fileType,
        sizeKb: sizeKb,
        date: meta.$2,
        schoolYear: schoolYearMatch?.group(1),
        postBackTarget: target,
      );
    } catch (e) {
      debugPrint('[DocumentService] Failed to parse document row: $e');
      return null;
    }
  }

  /// Parses e.g. `Predavanja 25.09.2026 / Autor-Mirela Mabić (`.
  static (String, DateTime?, String) _parseMeta(String rawMeta) {
    if (rawMeta.isEmpty) {
      return ('Ostalo', null, 'Nepoznat autor');
    }

    final parts = rawMeta.split('/ Autor');
    final left = parts.first.trim();
    final right =
        parts.length > 1 ? parts.sublist(1).join('/ Autor').trim() : '';

    var type = left;
    DateTime? date;

    final dateMatch = RegExp(r'(\d{1,2}\.\d{1,2}\.\d{4})$').firstMatch(left);
    if (dateMatch != null) {
      final dateText = dateMatch.group(1)!;
      type = left.replaceFirst(dateText, '').trim();
      date = parseDlwmsDate(dateText);
    }

    final author = right.replaceAll('(', '').replaceFirst('-', '').trim();

    return (
      type.isEmpty ? 'Ostalo' : type,
      date,
      author.isEmpty ? 'Nepoznat autor' : author,
    );
  }

  static List<DlwmsPagerLink> _parsePager(dom.Document document) {
    final pager = document.querySelector('#gridDokumenti tr.pgr td');
    if (pager == null) return const [];

    final links = <DlwmsPagerLink>[];
    for (final element in pager.children) {
      final label = element.text.trim();
      if (label.isEmpty) continue;

      if (element.localName == 'span') {
        links.add(DlwmsPagerLink(label: label));
      } else if (element.localName == 'a') {
        final target = postBackTarget(element.attributes['href']);
        if (target != null) {
          links.add(DlwmsPagerLink(label: label, target: target));
        }
      }
    }
    return links;
  }
}
