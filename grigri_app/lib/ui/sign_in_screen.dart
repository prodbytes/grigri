import 'package:flutter/material.dart';

import '../app_version.dart';
import '../data/auth.dart';
import '../theme.dart';
import 'common.dart';
import 'google_button/google_button.dart';

/// The sign-in screen: Google only (Google's own button on the web).
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  Future<void> _signIn(Auth auth) async {
    setState(() => _busy = true);
    await auth.signIn();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = StoreScope.of(context).auth;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    return ListenableBuilder(
      listenable: auth,
      builder: (context, _) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF203445), Mountain.night, Mountain.night],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const Text('🧗', style: TextStyle(fontSize: 64)),
                      const SizedBox(height: 8),
                      Text(
                        AppVersion.title,
                        style: text.displaySmall?.copyWith(
                          color: Mountain.sand,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l.signInTagline,
                        style: text.bodyLarge?.copyWith(
                          color: Mountain.granite,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ..._buttons(auth),
                      if (auth.error case final error?) ...[
                        const SizedBox(height: 16),
                        Text(
                          switch (error) {
                            SignInError.session => l.errorSession,
                            SignInError.google => l.errorSignIn,
                          },
                          style: const TextStyle(color: Mountain.clay),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buttons(Auth auth) {
    final l = context.l10n;
    return switch (auth.mode) {
      SignInMode.google => [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.login),
            label: Text(l.signInWithGoogle),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _busy ? null : () => _signIn(auth),
          ),
        ),
      ],
      SignInMode.googleWebButton => [
        SizedBox(height: 50, child: googleWebButton()),
      ],
    };
  }
}
