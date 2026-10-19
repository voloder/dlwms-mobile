import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the full text of [notification] (cards in lists).
void openAnnouncement(BuildContext context, DlwmsNotification notification) {
  final url = notification.url;
  if (url == null) return;
  context.push(
    Uri(path: '/home/obavijest', queryParameters: {'url': url}).toString(),
    extra: notification,
  );
}

/// Full text of one announcement (`opsirnije.aspx`). Opened from a list
/// (with the list item as a fallback while loading) or from a notification,
/// where only the [url] is known.
class NotificationDetailPage extends StatefulWidget {
  const NotificationDetailPage({super.key, required this.url, this.notification});

  final String url;
  final DlwmsNotification? notification;

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late Future<DlwmsNotificationDetail> _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _detail = context.read<NotificationProvider>().fetchDetail(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification ??
        DlwmsNotification(
          id: widget.url,
          title: '',
          content: '',
          dateTime: DateTime.now(),
          subject: '',
          author: '',
          authorEmail: '',
          url: widget.url,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Obavijest')),
      body: FutureBuilder<DlwmsNotificationDetail>(
        future: _detail,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: snapshot.error.toString(),
              onRetry: () async => setState(_load),
            );
          }
          return _DetailView(fallback: n, detail: snapshot.data!);
        },
      ),
    );
  }
}

class _DetailView extends StatelessWidget {
  const _DetailView({required this.fallback, required this.detail});

  final DlwmsNotification fallback;
  final DlwmsNotificationDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final title = detail.title.isNotEmpty ? detail.title : fallback.title;
    final subject = detail.subject.isNotEmpty ? detail.subject : fallback.subject;
    final author = detail.author.isNotEmpty ? detail.author : fallback.author;
    final email =
        detail.authorEmail.isNotEmpty ? detail.authorEmail : fallback.authorEmail;
    final date = detail.dateTime ?? fallback.dateTime;
    final body = detail.body.isNotEmpty ? detail.body : fallback.content;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SelectableText(
          title,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _Meta(Icons.calendar_today,
                DateFormat('dd.MM.yyyy HH:mm').format(date), muted),
            if (subject.isNotEmpty) _Meta(Icons.subject, subject, muted),
          ],
        ),
        if (author.isNotEmpty)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(author),
            subtitle: email.isEmpty ? null : Text(email),
            onTap: email.isEmpty
                ? null
                : () => _open(context, Uri(scheme: 'mailto', path: email)),
            onLongPress: email.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: email)),
          ),
        const Divider(height: 24),
        SelectableText(
          body.isEmpty ? 'Obavijest nema dodatnog teksta.' : body,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
        if (detail.links.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Linkovi', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final (label, uri) in detail.links)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.link),
              title: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(uri.host),
              onTap: () => _open(context, uri),
            ),
        ],
      ],
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nije moguće otvoriti $uri')),
      );
    }
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}
