import 'package:flutter/material.dart';

import 'app_version.dart';
import 'theme.dart';

void main() {
  runApp(const GrigriApp());
}

class GrigriApp extends StatelessWidget {
  const GrigriApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Dark only, for now: the mountain palette (theme.dart).
    return MaterialApp(
      title: AppVersion.title,
      debugShowCheckedModeBanner: false,
      theme: mountainTheme(),
      home: const HomeScreen(),
    );
  }
}

/// The only screen for now: the app's name and what it's for, with the
/// version underneath.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppVersion.title, style: text.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Find a partner to climb with',
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (AppVersion.version.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(AppVersion.version, style: text.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
