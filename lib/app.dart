import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/provider/document_provider.dart';
import 'package:dlwms_mobile/provider/nastava_provider.dart';
import 'package:dlwms_mobile/provider/notification_provider.dart';
import 'package:dlwms_mobile/provider/prisustvo_provider.dart';
import 'package:dlwms_mobile/provider/theme_provider.dart';
import 'package:dlwms_mobile/provider/uspjeh_provider.dart';
import 'package:dlwms_mobile/router.dart';
import 'package:dlwms_mobile/services/dlwms_client.dart';
import 'package:dlwms_mobile/theme/app_theme.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole app with its providers. [client] can be replaced (e.g. by a
/// client serving saved pages) for tests and screenshots.
Widget buildApp(SharedPreferences prefs, {DlwmsClient? client}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
      ChangeNotifierProvider(create: (_) => AuthProvider(prefs, client: client)),
      ChangeNotifierProxyProvider<AuthProvider, NotificationProvider>(
          create: (_) => NotificationProvider(),
          update: (_, auth, provider) => provider!..update(auth)),
      ChangeNotifierProxyProvider<AuthProvider, DokumentiProvider>(
          create: (_) => DokumentiProvider(),
          update: (_, auth, provider) => provider!..update(auth)),
      ChangeNotifierProxyProvider<AuthProvider, NastavaProvider>(
          create: (_) => NastavaProvider(),
          update: (_, auth, provider) => provider!..update(auth)),
      ChangeNotifierProxyProvider<AuthProvider, PrisustvoProvider>(
          create: (_) => PrisustvoProvider(),
          update: (_, auth, provider) => provider!..update(auth)),
      ChangeNotifierProxyProvider<AuthProvider, UspjehProvider>(
          create: (_) => UspjehProvider(),
          update: (_, auth, provider) => provider!..update(auth)),
    ],
    child: const DlwmsMobile(),
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
    final theme = context.watch<ThemeProvider>();

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // Only the wallpaper's primary colour is used, as a seed, so the
        // scheme is built the same way as for a chosen accent colour.
        theme.updateDeviceSeed(lightDynamic?.primary);

        return MaterialApp.router(
          title: 'DLWMS Mobile',
          debugShowCheckedModeBanner: false,
          themeMode: theme.themeMode,
          theme: buildAppTheme(theme.schemeFor(Brightness.light)),
          darkTheme: buildAppTheme(theme.schemeFor(Brightness.dark)),
          routerConfig: _router,
        );
      },
    );
  }
}
