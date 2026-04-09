class DlwmsNotification {
  final String id;
  final String title;
  final String content;
  final DateTime dateTime;
  final String subject;
  final String author;
  final String authorEmail;

  DlwmsNotification({
    required this.id,
    required this.title,
    required this.content,
    required this.dateTime,
    required this.subject,
    required this.author,
    required this.authorEmail,
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
    };
  }
}

