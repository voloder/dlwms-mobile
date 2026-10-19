import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/ui/widgets/common.dart';
import 'package:dlwms_mobile/ui/widgets/notification_card.dart';
import 'package:dlwms_mobile/ui/pages/notification_detail_page.dart';
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
                    : NotificationListener<ScrollNotification>(
                        // Loads the next DLWMS page when the end is near.
                        onNotification: (scroll) {
                          if (scroll.metrics.extentAfter < 400 &&
                              provider.hasMore &&
                              !provider.loadingMore &&
                              provider.loadMoreError == null) {
                            provider.loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: notifications.length + 1,
                          itemBuilder: (context, index) {
                            if (index == notifications.length) {
                              return _ListFooter(provider: provider);
                            }
                            final notification = notifications[index];
                            return NotificationCard(
                              notification: notification,
                              onTap: notification.url == null
                                  ? null
                                  : () =>
                                      openAnnouncement(context, notification),
                            );
                          },
                        ),
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

/// End of the list: loading indicator, retry, or a pointer to search.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.provider});

  final NotificationProvider provider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    final Widget child;
    if (provider.loadingMore) {
      child = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    } else if (provider.loadMoreError != null) {
      child = OutlinedButton.icon(
        onPressed: provider.loadMore,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Pokušaj ponovo'),
      );
    } else if (provider.hasMore) {
      child = OutlinedButton.icon(
        onPressed: provider.loadMore,
        icon: const Icon(Icons.expand_more_rounded),
        label: const Text('Učitaj starije'),
      );
    } else {
      child = TextButton.icon(
        onPressed: () => context.push('/home/pretraga'),
        icon: Icon(Icons.search_rounded, size: 18, color: muted),
        label: Text('Starije obavijesti pronađi u pretrazi',
            style: TextStyle(color: muted)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Center(child: child),
    );
  }
}
