import 'dart:io';

import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// Saves a downloaded DLWMS file to the app's cache and opens it with the
/// system's default app. Returns an error message, or null on success.
Future<String?> saveAndOpenFile(DlwmsFile file) async {
  final directory = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}dokumenti',
  );
  await directory.create(recursive: true);

  final path = '${directory.path}${Platform.pathSeparator}${file.fileName}';
  await File(path).writeAsBytes(file.bytes, flush: true);

  final result = await OpenFilex.open(path);
  switch (result.type) {
    case ResultType.done:
      return null;
    case ResultType.noAppToOpen:
      return 'Nema aplikacije koja može otvoriti "${file.fileName}".';
    case ResultType.fileNotFound:
    case ResultType.permissionDenied:
    case ResultType.error:
      return 'Nije moguće otvoriti dokument: ${result.message}';
  }
}
