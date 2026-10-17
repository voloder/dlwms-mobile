import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/provider/document_provider.dart';
import 'package:dlwms_mobile/provider/nastava_provider.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/provider/prisustvo_provider.dart';
import 'package:dlwms_mobile/provider/uspjeh_provider.dart';
import 'package:dlwms_mobile/router.dart';
import 'package:dlwms_mobile/services/background_service.dart';
import 'package:dlwms_mobile/services/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lets the background service tell the UI when new announcements arrive.
  BackgroundService.initCommunicationPort();
  await LocalNotifications.init();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(providers: [
      ChangeNotifierProvider(create: (context) => AuthProvider(prefs)),
      ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (context) => NotificationProvider(),
          update: (context, authProvider, notificationProvider) =>
              notificationProvider!..update(authProvider)),
      ChangeNotifierProxyProvider<AuthProvider, DokumentiProvider>(
          create: (context) => DokumentiProvider(),
          update: (context, authProvider, dokumentiProvider) =>
              dokumentiProvider!..update(authProvider)),
      ChangeNotifierProxyProvider<AuthProvider, NastavaProvider>(
          create: (context) => NastavaProvider(),
          update: (context, authProvider, nastavaProvider) =>
              nastavaProvider!..update(authProvider)),
      ChangeNotifierProxyProvider<AuthProvider, PrisustvoProvider>(
          create: (context) => PrisustvoProvider(),
          update: (context, authProvider, prisustvoProvider) =>
              prisustvoProvider!..update(authProvider)),
      ChangeNotifierProxyProvider<AuthProvider, UspjehProvider>(
          create: (context) => UspjehProvider(),
          update: (context, authProvider, uspjehProvider) =>
              uspjehProvider!..update(authProvider)),
    ], child: const DlwmsMobile()),
  );
}

class DlwmsMobile extends StatefulWidget {
  const DlwmsMobile({super.key});

  @override
  State<DlwmsMobile> createState() => _DlwmsMobileState();
}

class _DlwmsMobileState extends State<DlwmsMobile> {
  // Created once; GoRouter re-runs its redirect when AuthProvider changes.
  late final GoRouter _router = createRouter(context.read<AuthProvider>());

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DLWMS Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      ),
      routerConfig: _router,
    );
  }
}
