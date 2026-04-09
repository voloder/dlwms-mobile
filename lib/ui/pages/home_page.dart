import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../provider/notification_provider.dart';
import '../widgets/notification_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();

    context.read<NotificationProvider>().fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("DLWMS Mobile"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              notificationProvider.fetchNotifications();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              authProvider.logout();
              context.go('/login');
            },
          ),
        ],
      ),
      body: switch(notificationProvider.status) {
        NotificationProviderStatus.loading => const Center(child: CircularProgressIndicator()),
        NotificationProviderStatus.error => const Center(child: Text("Failed to load notifications")),
        NotificationProviderStatus.loaded when notificationProvider.notifications!.isEmpty =>
          const Center(child: Text("No notifications available")),
        NotificationProviderStatus.loaded => ListView.builder(
          itemCount: notificationProvider.notifications!.length,
          itemBuilder: (context, index) {
            final notification = notificationProvider.notifications![index];
            return NotificationCard(notification: notification);
          },
        ),
      },
    );
  }
}
