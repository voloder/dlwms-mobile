import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/util/file_opener.dart';
import 'package:flutter/material.dart';

/// Full-screen error with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered hint inside a scrollable, so pull-to-refresh still works.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.icon = Icons.inbox});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: Theme.of(context).hintColor),
                const SizedBox(height: 12),
                Text(text, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dropdown bound to a DLWMS `<select>`.
class DlwmsDropdown extends StatelessWidget {
  const DlwmsDropdown({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.includeEmpty = false,
    this.emptyLabel = 'Sve',
  });

  final String label;
  final List<DlwmsFilterOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  /// Whether the `value=""` option ("all") is offered.
  final bool includeEmpty;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<String>>[
      for (final option in options)
        if (option.value.isNotEmpty || includeEmpty)
          DropdownMenuItem(
            value: option.value,
            child: Text(
              option.value.isEmpty && option.label.isEmpty
                  ? emptyLabel
                  : option.label,
              overflow: TextOverflow.ellipsis,
            ),
          ),
    ];

    final hasValue = items.any((item) => item.value == value);

    return DropdownButtonFormField<String>(
      // Rebuild when the server-side selection changes.
      key: ValueKey('$label|$value|${options.length}'),
      initialValue: hasValue ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
      items: items,
      onChanged: enabled
          ? (newValue) {
              if (newValue != null && newValue != value) onChanged(newValue);
            }
          : null,
    );
  }
}

IconData iconForFileType(String type) {
  switch (type) {
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'archive':
      return Icons.folder_zip_outlined;
    case 'doc':
      return Icons.description_outlined;
    case 'sheet':
      return Icons.table_chart_outlined;
    case 'slides':
      return Icons.slideshow_outlined;
    case 'image':
      return Icons.image_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

/// Runs [download], saves the file and opens it; reports problems in a
/// SnackBar.
Future<void> downloadAndOpen(
  BuildContext context,
  Future<DlwmsFile> Function() download,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final file = await download();
    final error = await saveAndOpenFile(file);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.toString())));
  }
}

/// Shows a non-blocking error (used when a refresh fails but old data stays).
void showErrorSnack(BuildContext context, String? message) {
  if (message == null) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
