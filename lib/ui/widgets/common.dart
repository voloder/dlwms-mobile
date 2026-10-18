import 'package:dlwms_mobile/models/document.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/util/file_opener.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Full-screen error with a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconBadge(
              icon: Icons.cloud_off_rounded,
              background: scheme.errorContainer,
              foreground: scheme.onErrorContainer,
            ),
            const SizedBox(height: 16),
            Text('Nešto nije u redu',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centered hint inside a scrollable, so pull-to-refresh still works.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
  });

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconBadge(
                  icon: icon,
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Icon(icon, size: 34, color: foreground),
    );
  }
}

/// Small coloured heading above a group of content.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing, this.padding});

  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                letterSpacing: 0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Thin progress line shown while a postback is running.
class BusyBar extends StatelessWidget {
  const BusyBar({super.key, required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: busy ? const LinearProgressIndicator() : null,
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
    this.icon,
  });

  final String label;
  final List<DlwmsFilterOption> options;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final IconData? icon;

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
      borderRadius: BorderRadius.circular(AppRadius.medium),
      icon: const Icon(Icons.expand_more_rounded),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
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
      return Icons.picture_as_pdf_rounded;
    case 'archive':
      return Icons.folder_zip_rounded;
    case 'doc':
      return Icons.description_rounded;
    case 'sheet':
      return Icons.table_chart_rounded;
    case 'slides':
      return Icons.slideshow_rounded;
    case 'image':
      return Icons.image_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

/// Colour-coded square with the file type icon, like a file manager.
class FileTypeBadge extends StatelessWidget {
  const FileTypeBadge({super.key, required this.type, this.size = 44});

  final String type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    final Color base = switch (type) {
      'pdf' => const Color(0xFFD93025),
      'doc' => const Color(0xFF1A73E8),
      'sheet' => const Color(0xFF188038),
      'slides' => const Color(0xFFE37400),
      'archive' => const Color(0xFF8E6C00),
      'image' => const Color(0xFF9334E6),
      _ => scheme.primary,
    };

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: dark ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
      ),
      child: Icon(
        iconForFileType(type),
        size: size * 0.52,
        color: dark ? Color.lerp(base, Colors.white, 0.35) : base,
      ),
    );
  }
}

/// "upravo", "prije 5 min", "prije 3 h", "jučer u 14:20", "12.04.2026".
String relativeTime(DateTime time, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final diff = current.difference(time);

  if (diff.isNegative || diff.inMinutes < 1) return 'upravo';
  if (diff.inMinutes < 60) return 'prije ${diff.inMinutes} min';
  if (diff.inHours < 24 && current.day == time.day) {
    return 'prije ${diff.inHours} h';
  }

  final yesterday = DateTime(current.year, current.month, current.day)
      .subtract(const Duration(days: 1));
  if (!time.isBefore(yesterday)) {
    return 'jučer u ${DateFormat('HH:mm').format(time)}';
  }
  if (current.difference(time).inDays < 7) {
    const days = ['pon', 'uto', 'sri', 'čet', 'pet', 'sub', 'ned'];
    return '${days[time.weekday - 1]}, ${DateFormat('HH:mm').format(time)}';
  }
  return DateFormat(time.year == current.year ? 'dd.MM.' : 'dd.MM.yyyy')
      .format(time);
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
