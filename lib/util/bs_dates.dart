/// Bosnian day and month names, without needing intl's locale data (which
/// would have to be initialised in every isolate, including the background
/// service).
class BsDates {
  static const weekdays = [
    'ponedjeljak',
    'utorak',
    'srijeda',
    'četvrtak',
    'petak',
    'subota',
    'nedjelja',
  ];

  static const weekdaysShort = ['pon', 'uto', 'sri', 'čet', 'pet', 'sub', 'ned'];

  static const monthsShort = [
    'jan',
    'feb',
    'mar',
    'apr',
    'maj',
    'jun',
    'jul',
    'aug',
    'sep',
    'okt',
    'nov',
    'dec',
  ];

  static String weekday(DateTime date) => weekdays[date.weekday - 1];

  static String weekdayShort(DateTime date) => weekdaysShort[date.weekday - 1];

  static String monthShort(DateTime date) => monthsShort[date.month - 1];

  /// "danas", "sutra", "za 3 dana", "prije 2 dana" relative to [now].
  static String daysFromNow(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = day.difference(today).inDays;

    if (diff == 0) return 'danas';
    if (diff == 1) return 'sutra';
    if (diff == -1) return 'jučer';
    if (diff > 1) return 'za $diff ${_dana(diff)}';
    return 'prije ${-diff} ${_dana(-diff)}';
  }

  static String _dana(int n) => n % 10 == 1 && n % 100 != 11 ? 'dan' : 'dana';
}
