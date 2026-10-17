import 'package:dlwms_mobile/models/notification.dart';
import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/ui/pages/home_page.dart';
import 'package:dlwms_mobile/ui/pages/loading_page.dart';
import 'package:dlwms_mobile/ui/pages/login_page.dart';
import 'package:dlwms_mobile/ui/pages/notification_detail_page.dart';
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
          builder: (context, state) => const HomePage(),
          routes: [
            GoRoute(
              path: 'obavijest',
              redirect: (context, state) =>
                  state.extra is DlwmsNotification ? null : '/home',
              builder: (context, state) => NotificationDetailPage(
                notification: state.extra! as DlwmsNotification,
              ),
            ),
          ],
        ),
      ],
    );
