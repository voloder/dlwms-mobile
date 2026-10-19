/// Bottom navigation destinations, in display order.
enum AppTab { nastava, dokumenti, pocetna, ispiti, uspjeh }

/// Where tapping a notification should take the user. Stored as the
/// notification payload, so it must survive being serialised to a string.
class NotificationTarget {
  const NotificationTarget.announcement(String url)
      : announcementUrl = url,
        tab = AppTab.pocetna;

  const NotificationTarget.tab(this.tab) : announcementUrl = null;

  final String? announcementUrl;
  final AppTab tab;

  String encode() =>
      announcementUrl != null ? 'obavijest|$announcementUrl' : 'tab|${tab.name}';

  static NotificationTarget? decode(String? payload) {
    if (payload == null || payload.isEmpty) return null;

    // Versions before 0.3 stored the announcement URL directly.
    if (payload.startsWith('http')) {
      return NotificationTarget.announcement(payload);
    }

    final separator = payload.indexOf('|');
    if (separator < 0) return null;
    final kind = payload.substring(0, separator);
    final value = payload.substring(separator + 1);

    if (kind == 'obavijest' && value.isNotEmpty) {
      return NotificationTarget.announcement(value);
    }
    if (kind == 'tab') {
      for (final tab in AppTab.values) {
        if (tab.name == value) return NotificationTarget.tab(tab);
      }
    }
    return null;
  }

  /// go_router location for this target.
  String get location {
    final url = announcementUrl;
    if (url != null) {
      return Uri(path: '/home/obavijest', queryParameters: {'url': url})
          .toString();
    }
    return Uri(path: '/home', queryParameters: {'tab': tab.name}).toString();
  }
}
