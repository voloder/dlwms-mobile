import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:dlwms_mobile/ui/pages/home_page.dart';
import 'package:dlwms_mobile/ui/pages/loading_page.dart';
import 'package:dlwms_mobile/ui/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

GoRouter createRouter(BuildContext context) => GoRouter(
  refreshListenable: context.watch<AuthProvider>(),
    redirect: (context, state) {
      final authProvider = context.read<AuthProvider>();
      final isGoingToLogin = state.matchedLocation == '/login';

      // If still initializing, show loading page
      if (authProvider.state == AuthProviderState.initial) {
        return '/';
      }

      // If authenticated, allow access to home, redirect from login/root
      if (authProvider.state == AuthProviderState.authenticated) {
        if (isGoingToLogin || state.matchedLocation == '/') {
          return '/home';
        }
        return null;
      }

      // If unauthenticated or authenticating, redirect to login
      if (authProvider.state == AuthProviderState.unauthenticated ||
          authProvider.state == AuthProviderState.authenticating ||
          authProvider.state == AuthProviderState.error) {
        if (isGoingToLogin) {
          return null;
        }
        return '/login';
      }

      return null;
    },
    routes: [
      GoRoute(path: "/", builder: (context, state) => const LoadingPage()),
      GoRoute(path: "/login", builder: (context, state) => const LoginPage()),
      GoRoute(path: "/home", builder: (context, state) => const HomePage()),
    ]);
