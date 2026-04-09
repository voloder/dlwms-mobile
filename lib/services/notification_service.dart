import 'package:dlwms_mobile/models/notification.dart';
import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:intl/intl.dart';

class NotificationService {
  static List<DlwmsNotification> parseNotificationsFromHtml(String htmlContent) {
    final List<DlwmsNotification> notifications = [];

    try {
      final document = html_parser.parse(htmlContent);
      final newsItems = document.querySelectorAll('ul.newslist li');

      for (int i = 0; i < newsItems.length; i++) {
        final item = newsItems[i];

        try {
          // Title & link
          dom.Element? titleElement = item.querySelector('a.linkButton') ??
              item.querySelector('a[class*="link"]') ??
              item.querySelector('a');
          final title = titleElement?.text.trim() ?? '';
          final titleLink = titleElement?.attributes['href'] ?? '';
          if (title.isEmpty) continue;

          // Meta info
          final metaElements = item.querySelectorAll('span.meta');
          String dateStr = metaElements.isNotEmpty ? metaElements[0].text.trim() : '';
          String subject = metaElements.length > 1 ? metaElements[1].text.trim() : '';

          // Author & email
          final authorElement = item.querySelector('a[href*="mailto"]');
          final author = authorElement?.text.trim() ?? 'Unknown';
          final authorEmail = authorElement?.attributes['href']?.replaceFirst('mailto:', '') ?? '';

          // Content
          final content = item.querySelector('div.abstract')?.text.trim() ?? 'No content available';

          final dateTime = _parseDate(dateStr) ?? DateTime.now();

          notifications.add(DlwmsNotification(
            id: titleLink.hashCode.toString(),
            title: title,
            content: content,
            dateTime: dateTime,
            subject: subject.isEmpty ? 'General' : subject,
            author: author,
            authorEmail: authorEmail,
          ));
        } catch (e) {
          debugPrint('[NotificationService] Error parsing item $i: $e');
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Fatal error parsing HTML: $e');
      return [];
    }

    return notifications;
  }


  static DateTime? _parseDate(String dateStr) {
    dateStr = dateStr.replaceAll('-', '').trim();

    final format = DateFormat('dd.MM.yyyy HH:mm');
    return format.parseLoose(dateStr);
  }
}