import 'document.dart';
import 'notification.dart';

/// A recent material in the "Novi dokumenti iz predmeta" list.
class DlwmsMaterial {
  const DlwmsMaterial({
    required this.title,
    required this.fileType,
    this.date,
    this.postBackTarget,
  });

  final String title;
  final String fileType;
  final DateTime? date;
  final String? postBackTarget;
}

class NastavaPageData {
  const NastavaPageData({
    required this.yearOptions,
    required this.subjectOptions,
    required this.notifications,
    required this.materials,
  });

  final List<DlwmsFilterOption> yearOptions;
  final List<DlwmsFilterOption> subjectOptions;
  final List<DlwmsNotification> notifications;
  final List<DlwmsMaterial> materials;
}
