import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/html_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;

class NotificationService {
  /// Parses the `ul.newslist` announcements found on the home page
  /// (`default.aspx`) and on the per-subject Nastava page.
  ///
  /// [fallbackSubject] is used when an item has no subject label (the Nastava
  /// page omits it because the subject is selected above the list).
  static List<DlwmsNotification> parseNotifications(
    DlwmsPage page, {
    String? fallbackSubject,
  }) {
    final notifications = <DlwmsNotification>[];

    var items = page.document.querySelectorAll('#dgObavijesti ul.newslist li');
    if (items.isEmpty) {
      items = page.document.querySelectorAll('ul.newslist li');
    }
    for (var i = 0; i < items.length; i++) {
      try {
        final parsed = _parseItem(items[i], page, fallbackSubject);
        if (parsed != null) notifications.add(parsed);
      } catch (e) {
        debugPrint('[NotificationService] Error parsing item $i: $e');
      }
    }

    return notifications;
  }

  static DlwmsNotification? _parseItem(
    dom.Element item,
    DlwmsPage page,
    String? fallbackSubject,
  ) {
    final titleElement = item.querySelector('a#lnkNaslov') ??
        item.querySelector('a.linkButton') ??
        item.querySelector('a');
    final title = titleElement?.text.trim() ?? '';
    if (title.isEmpty) return null;

    final href = titleElement?.attributes['href'];
    final url = (href == null || href.startsWith('javascript'))
        ? null
        : page.resolve(href).toString();

    final dateRaw = textOf(item, 'span#lblDatum');
    final subject = textOf(item, 'span#lblPredmet');

    final authorElement = item.querySelector('a[href^="mailto"]');
    final author = authorElement?.text.trim() ?? '';
    final authorEmail =
        authorElement?.attributes['href']?.replaceFirst('mailto:', '') ?? '';

    final content = htmlToText(item.querySelector('.abstract'));
    final dateTime = parseDlwmsDate(dateRaw) ?? DateTime.now();

    return DlwmsNotification(
      id: '${dateRaw.replaceAll('-', '').trim()}|$title',
      title: title,
      content: content,
      dateTime: dateTime,
      subject: subject.isNotEmpty ? subject : (fallbackSubject ?? 'Opće'),
      author: author.isEmpty ? 'Nepoznat autor' : author,
      authorEmail: authorEmail,
      url: url,
    );
  }

  /// Parses the full announcement page (`obavijesti/opsirnije.aspx`).
  static DlwmsNotificationDetail parseDetail(DlwmsPage page) {
    final document = page.document;
    final root = document.documentElement!;

    final body = document.querySelector('#Panel1');

    final links = <(String, Uri)>[];
    for (final link in body?.querySelectorAll('a[href]') ?? <dom.Element>[]) {
      final href = link.attributes['href']!.trim();
      if (href.isEmpty || href.startsWith('javascript') || href == '#') {
        continue;
      }
      final label = link.text.trim();
      final uri = page.resolve(href);
      links.add((label.isEmpty ? uri.toString() : label, uri));
    }

    final authorElement = document.querySelector('#linkNapisao') ??
        document.querySelector('a.meta[href^="mailto"]');

    return DlwmsNotificationDetail(
      title: textOf(root, '#lblNaslov'),
      body: htmlToText(body),
      subject: textOf(root, '#lblPredmet').isNotEmpty
          ? textOf(root, '#lblPredmet')
          : textOf(root, '#lblPredmetNaziv'),
      author: authorElement?.text.trim() ?? '',
      authorEmail:
          authorElement?.attributes['href']?.replaceFirst('mailto:', '') ?? '',
      dateTime: parseDlwmsDate(textOf(root, '#lblDatum')),
      links: links,
    );
  }
}
