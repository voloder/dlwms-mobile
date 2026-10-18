import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/app_logo.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/error_banner.dart';
import '../widgets/login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late final TextEditingController usernameController;
  final TextEditingController passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(
      text: context.read<AuthProvider>().username ?? '',
    );
  }

  void _submit(AuthProvider authProvider) {
    FocusScope.of(context).unfocus();
    authProvider.login(usernameController.text, passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.state == AuthProviderState.authenticating;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo()),
                    const SizedBox(height: 28),
                    Text(
                      'Dobro došli',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Prijavite se svojim DLWMS podacima',
                      textAlign: TextAlign.center,
                      style:
                          theme.textTheme.bodyLarge?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 36),
                    CustomTextField(
                      controller: usernameController,
                      labelText: "Broj indeksa",
                      hintText: "npr. IB230001",
                      prefixIcon: Icons.badge_outlined,
                      enabled: !isLoading,
                    ),
                    const SizedBox(height: 14),
                    CustomTextField(
                      controller: passwordController,
                      labelText: "Šifra",
                      hintText: "Unesite šifru",
                      prefixIcon: Icons.lock_outline_rounded,
                      isPassword: true,
                      enabled: !isLoading,
                      onSubmitted: (_) => _submit(authProvider),
                    ),
                    const SizedBox(height: 20),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: authProvider.state == AuthProviderState.error
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ErrorBanner(
                                message: authProvider.errorMessage ??
                                    "Neispravan broj indeksa ili šifra.",
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                    LoginButton(
                      isLoading: isLoading,
                      onPressed: () => _submit(authProvider),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_outlined,
                            size: 16, color: muted),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Podaci se šalju samo na fit.ba',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: muted),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Neslužbena aplikacija, nije povezana s FIT-om.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
