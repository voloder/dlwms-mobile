import 'dart:io';

import 'package:dlwms_mobile/models/ispit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Opens the phone's calendar app with a new event filled in (Android's
/// "insert event" screen, handled in MainActivity). Nothing is saved until
/// the user confirms in the calendar app.
class CalendarService {
  static const MethodChannel _channel =
      MethodChannel('dev.voloder.dlwms/calendar');

  /// Exams on DLWMS have no end time; assume two hours.
  static const Duration examLength = Duration(hours: 2);

  /// Lets tests and screenshots show the calendar button off Android.
  @visibleForTesting
  static bool? debugSupported;

  static bool get isSupported =>
      debugSupported ?? (!kIsWeb && Platform.isAndroid);

  /// Returns false if no calendar app could handle the request.
  static Future<bool> addExam(ExamTerm term, {String? periodName}) async {
    final start = term.dateTime;
    if (!isSupported || start == null) return false;

    try {
      final ok = await _channel.invokeMethod<bool>('insertEvent', {
        'title': 'Ispit: ${term.subject}',
        'description': [
          if (periodName != null && periodName.isNotEmpty) periodName,
          'Termin iz DLWMS-a (fit.ba)',
        ].join('\n'),
        'location': term.subject.toLowerCase().contains('online')
            ? 'Online'
            : 'FIT Mostar',
        'begin': start.millisecondsSinceEpoch,
        'end': start.add(examLength).millisecondsSinceEpoch,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
