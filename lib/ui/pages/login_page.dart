import 'package:dlwms_mobile/provider/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/custom_text_field.dart';
import '../widgets/error_banner.dart';
import '../widgets/login_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthProviderStatus.authenticating;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("DLWMS Mobile", style: Theme.of(context).textTheme.headlineMedium),

                  const SizedBox(height: 48),

                  // Username Field
                  CustomTextField(
                    controller: usernameController,
                    labelText: "Broj Indeksa",
                    hintText: "Unesite broj indeksa",
                    prefixIcon: Icons.person,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 20),

                  // Password Field
                  CustomTextField(
                    controller: passwordController,
                    labelText: "Šifra",
                    hintText: "Unesite šifru",
                    prefixIcon: Icons.lock,
                    isPassword: true,
                    enabled: !isLoading,
                  ),
                  const SizedBox(height: 32),

                  // Error Message
                  if (authProvider.status == AuthProviderStatus.error) ...[
                    ErrorBanner(
                      message: "Neispravan broj indeksa ili šifra. Pokušajte ponovo.",
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Login Button
                  LoginButton(
                    isLoading: isLoading,
                    onPressed: () {
                      authProvider.login(
                        usernameController.text,
                        passwordController.text,
                      );
                    },
                  ),
                ],
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
