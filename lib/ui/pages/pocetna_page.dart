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
      NotificationProviderState.loaded => RefreshIndicator(
          onRefresh: () => provider.fetchNotifications(silent: true),
          child: notifications.isEmpty
              ? const EmptyState(text: 'Nema obavijesti.')
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
    };
  }
}
