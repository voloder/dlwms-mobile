import 'package:dlwms_mobile/ui/widgets/app_logo.dart';
import 'package:flutter/material.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(),
            const SizedBox(height: 28),
            Text('DLWMS Mobile', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 24),
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Prijava u toku...',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
