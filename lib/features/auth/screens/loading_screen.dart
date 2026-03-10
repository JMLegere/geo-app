import 'package:flutter/material.dart';

import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// Hydration loading screen — shown between login and map while game data loads.
///
/// Pure presentation widget: no Riverpod, no timeout, no retry logic.
/// Wired into the auth-state switch in `EarthNovaApp` by Task 14.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              GameIcons.globe,
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: 48),
            ),
            Spacing.gapXl,
            Text(
              'EarthNova',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            Spacing.gapMd,
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: colorScheme.primary,
              ),
            ),
            Spacing.gapLg,
            Text(
              'Loading your world...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
