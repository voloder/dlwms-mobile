import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/services/notification_target.dart';
import 'package:dlwms_mobile/ui/pages/arhiva_search_page.dart';
import 'package:dlwms_mobile/ui/pages/home_page.dart';
import 'package:dlwms_mobile/ui/pages/loading_page.dart';
import 'package:dlwms_mobile/ui/pages/login_page.dart';
import 'package:dlwms_mobile/ui/pages/notification_detail_page.dart';
import 'package:dlwms_mobile/ui/pages/settings_page.dart';
import 'package:go_router/go_router.dart';

GoRouter createRouter(AuthProvider authProvider) => GoRouter(
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isGoingToLogin = state.matchedLocation == '/login';

        // Still restoring a saved session: show the loading page.
        if (authProvider.state == AuthProviderState.initial) {
          return '/';
        }

        if (authProvider.state == AuthProviderState.authenticated) {
          if (isGoingToLogin || state.matchedLocation == '/') {
            return '/home';
          }
          return null;
        }

        // Unauthenticated, authenticating or failed: stay on/go to login.
        return isGoingToLogin ? null : '/login';
      },
      routes: [
        GoRoute(path: '/', builder: (context, state) => const LoadingPage()),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/home',
          builder: (context, state) {
            final tabName = state.uri.queryParameters['tab'];
            final tab =
                AppTab.values.where((t) => t.name == tabName).firstOrNull;
            return HomePage(tab: tab, request: state.uri.queryParameters['n']);
          },
          routes: [
            GoRoute(
              path: 'postavke',
              builder: (context, state) => const SettingsPage(),
            ),
            GoRoute(
              path: 'pretraga',
              builder: (context, state) => const ArhivaSearchPage(),
            ),
            GoRoute(
              path: 'obavijest',
              redirect: (context, state) {
                final url = state.uri.queryParameters['url'];
                return url == null || url.isEmpty ? '/home' : null;
              },
              builder: (context, state) => NotificationDetailPage(
                url: state.uri.queryParameters['url']!,
                notification: state.extra is DlwmsNotification
                    ? state.extra! as DlwmsNotification
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
