class DlwmsNotification {
  /// Stable identifier (`date|title`) used to detect new announcements.
  final String id;
  final String title;
  final String content;
  final DateTime dateTime;
  final String subject;
  final String author;
  final String authorEmail;

  /// Absolute link to the full announcement (`opsirnije.aspx?...`).
  final String? url;

  DlwmsNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.dateTime,
    required this.subject,
    required this.author,
    required this.authorEmail,
    this.url,
  });

  factory DlwmsNotification.fromJson(Map<String, dynamic> json) {
    return DlwmsNotification(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
      subject: json['subject'] ?? '',
      author: json['author'] ?? '',
      authorEmail: json['authorEmail'] ?? '',
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'dateTime': dateTime.toIso8601String(),
      'subject': subject,
      'author': author,
      'authorEmail': authorEmail,
      'url': url,
    };
  }
}

/// Full announcement as shown on `opsirnije.aspx`.
class DlwmsNotificationDetail {
  const DlwmsNotificationDetail({
    required this.title,
    required this.body,
    required this.subject,
    required this.author,
    required this.authorEmail,
    required this.links,
    this.dateTime,
  });

  final String title;
  final String body;
  final String subject;
  final String author;
  final String authorEmail;
  final DateTime? dateTime;

  /// Links found inside the announcement body (label, absolute URL).
  final List<(String, Uri)> links;
}
