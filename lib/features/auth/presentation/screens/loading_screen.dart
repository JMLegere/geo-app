import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';
import 'package:earth_nova/shared/widgets/loading_dots.dart';

class LoadingScreen extends ConsumerWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: 'loading_screen',
      observability: obs,
      builder: (_) => Scaffold(
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
      ),
    );
  }
}
