import 'document.dart';

class PrisustvoSubject {
  const PrisustvoSubject({
    required this.name,
    required this.percentage,
    this.postBackTarget,
  });

  final String name;

  /// 0–100.
  final int percentage;

  /// Postback that opens the per-subject breakdown.
  final String? postBackTarget;
}

/// One line of the per-subject breakdown (e.g. "Predavanja (2/2) 100%").
class PrisustvoDetailItem {
  const PrisustvoDetailItem({
    required this.kind,
    required this.percentage,
    this.attended,
    this.total,
  });

  final String kind;
  final int percentage;
  final int? attended;
  final int? total;
}

class PrisustvoDetail {
  const PrisustvoDetail({required this.subject, required this.items});

  final String subject;
  final List<PrisustvoDetailItem> items;
}

class PrisustvoPageData {
  const PrisustvoPageData({
    required this.yearOptions,
    required this.subjects,
    this.detail,
  });

  final List<DlwmsFilterOption> yearOptions;
  final List<PrisustvoSubject> subjects;
  final PrisustvoDetail? detail;
}
