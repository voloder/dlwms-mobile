import 'package:dlwms_mobile/models/document.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:intl/intl.dart';

class DocumentService {
  static DokumentiPageData parseDokumentiPage(String htmlContent) {
    final document = html_parser.parse(htmlContent);

    final subjectOptions = _parseOptions(document, '#ddlPredmeti option');
    final typeOptions = _parseOptions(document, '#listVrsta option');
    final schoolYearOptions =
        _parseOptions(document, '#ddlSkolskeGodine option');

    final documents = <DlwmsDocument>[];
    final rows = document.querySelectorAll('#gridDokumenti contenttemplate');

    for (final row in rows) {
      final parsed = _parseDocumentRow(row);
      if (parsed != null) {
        documents.add(parsed);
      }
    }

    final pager = _parsePager(document);

    return DokumentiPageData(
      documents: documents,
      subjectOptions: subjectOptions,
      typeOptions: typeOptions,
      schoolYearOptions: schoolYearOptions,
      currentPage: pager.$1,
      totalPages: pager.$2,
    );
  }

  static List<DlwmsFilterOption> _parseOptions(
      dom.Document document, String selector) {
    final options = document.querySelectorAll(selector);

    return options
        .map(
          (option) => DlwmsFilterOption(
            label: option.text.trim(),
            value: option.attributes['value'] ?? '',
            isSelected: option.attributes.containsKey('selected'),
          ),
        )
        .toList(growable: false);
  }

  static DlwmsDocument? _parseDocumentRow(dom.Element row) {
    try {
      final titleElement = row.querySelector('a#lbtnNaslov');
      final title = titleElement?.text.trim() ?? '';
      if (title.isEmpty) {
        return null;
      }

      final href = titleElement?.attributes['href'] ?? '';
      final targetMatch = RegExp(r"__doPostBack\('([^']+)'").firstMatch(href);
      final postBackTarget = targetMatch?.group(1);

      final iconSrc = row.querySelector('img#imgType')?.attributes['src'] ?? '';
      final fileType = _parseFileType(iconSrc);

      final metaText = row.querySelector('span#lblVrsta')?.text.trim() ?? '';
      final meta = _parseMeta(metaText);

      final sizeText =
          row.querySelector('span#lblDokumentSize')?.text.trim() ?? '0';
      final sizeKb = int.tryParse(sizeText) ?? 0;

      final schoolYearMatch = RegExp(r'(\d{4}/\d{4})').firstMatch(title);

      return DlwmsDocument(
        id: postBackTarget ?? title,
        title: title,
        type: meta.$1,
        author: meta.$3,
        fileType: fileType,
        sizeKb: sizeKb,
        date: meta.$2,
        schoolYear: schoolYearMatch?.group(1),
        postBackTarget: postBackTarget,
      );
    } catch (e) {
      debugPrint('[DocumentService] Failed to parse document row: $e');
      return null;
    }
  }

  static (String, DateTime?, String) _parseMeta(String rawMeta) {
    if (rawMeta.isEmpty) {
      return ('Ostalo', null, 'Nepoznat autor');
    }

    final parts = rawMeta.split('/ Autor');
    final left = parts.first.trim();
    final right =
        parts.length > 1 ? parts.sublist(1).join('/ Autor').trim() : '';

    String type = left;
    DateTime? date;

    final dateMatch = RegExp(r'(\d{2}\.\d{2}\.\d{4})$').firstMatch(left);
    if (dateMatch != null) {
      final dateText = dateMatch.group(1)!;
      type = left.replaceFirst(dateText, '').trim();
      date = _parseDate(dateText);
    }

    final author = right.replaceAll('(', '').replaceFirst('-', '').trim();

    return (
      type.isEmpty ? 'Ostalo' : type,
      date,
      author.isEmpty ? 'Nepoznat autor' : author,
    );
  }

  static DateTime? _parseDate(String value) {
    try {
      return DateFormat('dd.MM.yyyy').parseStrict(value);
    } catch (_) {
      return null;
    }
  }

  static String _parseFileType(String iconSrc) {
    final icon = iconSrc.toLowerCase();
    if (icon.contains('pdf')) {
      return 'pdf';
    }
    if (icon.contains('rar') || icon.contains('zip') || icon.contains('box')) {
      return 'archive';
    }
    if (icon.contains('doc')) {
      return 'doc';
    }

    return 'file';
  }

  static (int, int) _parsePager(dom.Document document) {
    final pager = document.querySelector('#gridDokumenti tr.pgr td');
    if (pager == null) {
      return (1, 1);
    }

    int currentPage = 1;
    int totalPages = 1;

    for (final element in pager.children) {
      final label = element.text.trim();
      final page = int.tryParse(label);
      if (page == null) {
        continue;
      }

      if (element.localName == 'span') {
        currentPage = page;
      }

      if (page > totalPages) {
        totalPages = page;
      }
    }

    return (currentPage, totalPages);
  }
}
