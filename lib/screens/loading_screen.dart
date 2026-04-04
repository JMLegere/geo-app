import 'package:flutter/material.dart';
import 'package:earth_nova/shared/app_theme.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/widgets/loading_dots.dart';

/// Loading screen — shown between login and pack.
/// Animated ellipsis tells the user the app is working.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: Spacing.md),
            const Text(
              'Loading Pack',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const LoadingDots(),
          ],
        ),
      ),
    );
  }
}
