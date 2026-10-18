import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';

class NotificationCard extends StatelessWidget {
  final DlwmsNotification notification;
  final VoidCallback? onTap;
  final bool showSubject;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.showSubject = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    final hasSubject = showSubject && notification.subject.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Card(
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SubjectAvatar(
                      subject: hasSubject ? notification.subject : '',
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hasSubject
                                ? notification.subject
                                : (showSubject ? 'Opća obavijest' : notification.author),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          Text(
                            [
                              relativeTime(notification.dateTime),
                              if (showSubject && notification.author.isNotEmpty)
                                notification.author,
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notification.title,
                  style: theme.textTheme.titleMedium?.copyWith(height: 1.25),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notification.content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    notification.content,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: muted, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Coloured initials of the subject ("Razvoj softvera II" → "RS2"); a megaphone
/// for faculty-wide notices.
class SubjectAvatar extends StatelessWidget {
  const SubjectAvatar({super.key, required this.subject});

  final String subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final palette = [
      (scheme.primaryContainer, scheme.onPrimaryContainer),
      (scheme.secondaryContainer, scheme.onSecondaryContainer),
      (scheme.surfaceContainerHighest, scheme.primary),
    ];
    final (background, foreground) = subject.isEmpty
        ? (scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : palette[subject.hashCode.abs() % palette.length];

    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.small + 2),
      ),
      child: subject.isEmpty
          ? Icon(Icons.campaign_outlined, size: 20, color: foreground)
          : Text(
              initials(subject),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
            ),
    );
  }

  /// First letters of the first two words, plus a roman numeral as a digit:
  /// "Razvoj softvera II" → "RS2", "Kompjuterska grafika" → "KG".
  static String initials(String subject) {
    final roman = RegExp(r'^[IVX]+$');
    final words = subject.split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final letters = words
        .where((w) => !roman.hasMatch(w) && w.length > 2)
        .take(2)
        .map((w) => w.substring(0, 1).toUpperCase())
        .join();
    final numeral = words.where(roman.hasMatch).lastOrNull;
    final result = letters + (numeral == null ? '' : '${_roman(numeral)}');
    return result.isEmpty ? subject.substring(0, 1).toUpperCase() : result;
  }

  static int _roman(String value) {
    const map = {'I': 1, 'V': 5, 'X': 10};
    var total = 0;
    for (var i = 0; i < value.length; i++) {
      final current = map[value[i]]!;
      final next = i + 1 < value.length ? map[value[i + 1]]! : 0;
      total += current < next ? -current : current;
    }
    return total;
  }
}
