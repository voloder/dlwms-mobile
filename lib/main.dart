import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/provider/document_provider.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/router.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    ], child: const DlwmsMobile()),
  );
}

class DlwmsMobile extends StatelessWidget {
  const DlwmsMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: "DLWMS Mobile",
      theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue, brightness: Brightness.dark)),
      routerConfig: createRouter(context),
    );
  }
}
