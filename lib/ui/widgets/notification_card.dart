import 'package:dlwms_mobile/models/notification.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    final muted = theme.colorScheme.onSurfaceVariant;
    final metaStyle = theme.textTheme.bodySmall?.copyWith(color: muted);

    Widget meta(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(icon, size: 14, color: muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  text,
                  style: metaStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              meta(
                Icons.calendar_today,
                DateFormat('dd.MM.yyyy HH:mm').format(notification.dateTime),
              ),
              if (showSubject && notification.subject.isNotEmpty)
                meta(Icons.subject, notification.subject),
              if (notification.author.isNotEmpty)
                meta(Icons.person_outline, notification.author),
              if (notification.content.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  notification.content,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
