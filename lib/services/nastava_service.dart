import 'package:dlwms_mobile/models/nastava.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/services/notification_service.dart';
import 'package:dlwms_mobile/util/html_utils.dart';

class NastavaService {
  /// Parses `nastava/index.aspx`: year/subject dropdowns, the subject's
  /// announcements and its newest materials.
  static NastavaPageData parseNastavaPage(DlwmsPage page) {
    final document = page.document;

    final yearOptions = parseSelectOptions(document, '#listGodina');
    final subjectOptions = parseSelectOptions(document, '#ddlPredmeti');
    final subject = selectedOption(subjectOptions)?.label;

    final materials = <DlwmsMaterial>[];
    final table = document.querySelector('#dgMaterijali');
    for (final link in table?.querySelectorAll('a#linkNaslov') ?? const []) {
      final title = link.text.trim();
      if (title.isEmpty) continue;

      // The icon and date live in the same inner <table> as the link.
      var container = link.parent;
      while (container != null && container.localName != 'table') {
        container = container.parent;
      }
      final scope = container ?? link.parent!;

      materials.add(
        DlwmsMaterial(
          title: title,
          fileType:
              fileTypeFromIcon(scope.querySelector('img')?.attributes['src']),
          date: parseDlwmsDate(textOf(scope, 'span#lblItemDatum')),
          postBackTarget: postBackTarget(link.attributes['href']),
        ),
      );
    }

    return NastavaPageData(
      yearOptions: yearOptions,
      subjectOptions: subjectOptions,
      notifications: NotificationService.parseNotifications(
        page,
        fallbackSubject: subject,
      ),
      materials: materials,
    );
  }
}
