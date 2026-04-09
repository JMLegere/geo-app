import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

/// Stub screen for features not yet built.
class StubScreen extends ConsumerWidget {
  const StubScreen({required this.label, super.key});
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    return ObservableScreen(
      screenName: 'stub_screen',
      observability: obs,
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$label — Coming soon',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'More discoveries on the way!',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
