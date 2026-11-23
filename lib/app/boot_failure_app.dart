/// What the app shows when boot itself fails.
///
/// Without this, a throw inside `openAppServices` (a locked database, a
/// missing schema asset, an unsupported platform) leaves a blank window with no
/// way to tell the user anything went wrong.
library;

import 'package:flutter/material.dart';

import '../ui/kit/primary_button.dart';
import '../ui/theme/app_theme.dart';

/// Minimal, themed "could not start" screen with a retry.
class BootFailureApp extends StatelessWidget {
  const BootFailureApp({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Health Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    'Could not start',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'The household data is still on this device — this is a '
                    'startup problem, not a deletion.',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('$error', style: AppTextStyles.caption),
                  const SizedBox(height: AppSpacing.lg),
                  PrimaryButton(
                    key: const ValueKey<String>('boot-retry'),
                    label: 'Try again',
                    onPressed: onRetry,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
