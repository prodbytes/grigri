import 'package:flutter/material.dart';

import '../app_version.dart';
import '../data/auth.dart';
import '../theme.dart';
import 'common.dart';
import 'google_button/google_button.dart';

/// The sign-in screen: Google only (Google's own button on the web), or,
/// in a local build without a Google client ID, the local API's dev
/// sign-in with an email.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _signIn(Auth auth) async {
    setState(() => _busy = true);
    await auth.signIn(devEmail: _email.text);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = StoreScope.of(context).auth;
    final text = Theme.of(context).textTheme;
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
                        'Find climbing partners: make a plan, or swipe right '
                        'on one, and climb together.',
                        style: text.bodyLarge?.copyWith(
                          color: Mountain.granite,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      ..._buttons(auth, text),
                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          auth.error!,
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

  List<Widget> _buttons(Auth auth, TextTheme text) => switch (auth.mode) {
    SignInMode.google => [
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
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
    SignInMode.dev => [
      Text(
        'DEV SIGN-IN · LOCAL API ONLY',
        style: text.labelSmall?.copyWith(
          color: Mountain.tan,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'someone@example.com',
        ),
        onSubmitted: (_) => _signIn(auth),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _busy ? null : () => _signIn(auth),
          child: const Text('Dev sign-in'),
        ),
      ),
    ],
    SignInMode.unconfigured => [
      const Text(
        'Sign-in isn\'t set up in this build (no Google client ID).',
        style: TextStyle(color: Mountain.clay),
        textAlign: TextAlign.center,
      ),
    ],
  };
}
