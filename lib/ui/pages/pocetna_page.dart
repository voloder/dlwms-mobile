import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/notification_provider.dart';
import '../widgets/notification_card.dart';

class PocetnaPage extends StatefulWidget {
  const PocetnaPage({super.key});

  @override
  State<PocetnaPage> createState() => _PocetnaPageState();
}

class _PocetnaPageState extends State<PocetnaPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();

    return switch(notificationProvider.state) {
      NotificationProviderState.loading => const Center(child: CircularProgressIndicator()),
      NotificationProviderState.error => const Center(child: Text("Failed to load notifications")),
      NotificationProviderState.loaded when notificationProvider.notifications!.isEmpty =>
      const Center(child: Text("No notifications available")),
      NotificationProviderState.loaded =>
          RefreshIndicator(
            displacement: 50,
            onRefresh: () => notificationProvider.fetchNotifications(),
            child: ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: notificationProvider.notifications!.length,
              itemBuilder: (context, index) {
                final notification = notificationProvider.notifications![index];
                return NotificationCard(notification: notification);
              },
            ),
          )
    };
  }
}
