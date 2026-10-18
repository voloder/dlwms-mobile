import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/ui/widgets/notification_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class PocetnaPage extends StatefulWidget {
  const PocetnaPage({super.key});

  @override
  State<PocetnaPage> createState() => _PocetnaPageState();
}

class _PocetnaPageState extends State<PocetnaPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<NotificationProvider>();
    final notifications = provider.notifications ?? const [];

    return switch (provider.state) {
      NotificationProviderState.loading =>
        const Center(child: CircularProgressIndicator()),
      NotificationProviderState.error => ErrorState(
          message: provider.errorMessage ?? 'Obavijesti nije moguće učitati.',
          onRetry: provider.fetchNotifications,
        ),
      NotificationProviderState.loaded => Column(
          children: [
            if (provider.relevantOnly) _FilterBanner(provider: provider),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => provider.fetchNotifications(silent: true),
                child: notifications.isEmpty
                    ? EmptyState(
                        text: provider.relevantOnly && provider.hiddenCount > 0
                            ? 'Nema relevantnih obavijesti.'
                            : 'Nema obavijesti.',
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return NotificationCard(
                            notification: notification,
                            onTap: notification.url == null
                                ? null
                                : () => context.push('/home/obavijest',
                                    extra: notification),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
    };
  }
}

/// Tells the user the list is filtered and lets them switch the filter off.
class _FilterBanner extends StatelessWidget {
  const _FilterBanner({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hidden = provider.hiddenCount;

    return Material(
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        child: Row(
          children: [
            Icon(Icons.filter_alt,
                size: 18, color: theme.colorScheme.onSecondaryContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hidden == 0
                    ? 'Samo relevantne obavijesti'
                    : 'Samo relevantne obavijesti · skriveno: $hidden',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSecondaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => provider.setRelevantOnly(false),
              child: const Text('Prikaži sve'),
            ),
          ],
        ),
      ),
    );
  }
}
