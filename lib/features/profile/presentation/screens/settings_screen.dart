import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';

/// Settings screen — sign out only in v3 MVP.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final obs = ref.watch(appObservabilityProvider);

    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      ref.read(authProvider.notifier).obs.log(event, category, data: data);
    }

    return ObservableScreen(
      screenName: 'settings_screen',
      observability: obs,
      builder: (_) => Scaffold(
        backgroundColor: AppTheme.surface,
        appBar: AppBar(
          title: const Text('Settings'),
          backgroundColor: AppTheme.surfaceContainer,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person,
                    size: 96, color: AppTheme.onSurfaceVariant),
                const SizedBox(height: Spacing.md),
                Text(
                  'Explorer',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: Spacing.xxxl),
                OutlinedButton(
                  onPressed: ObservableInteraction.wrapVoidCallback(
                    logger: logger,
                    screenName: 'settings_screen',
                    widgetName: 'sign_out_button',
                    actionType: 'sign_out_dialog_open',
                    callback: () => _showSignOutDialog(context, ref, logger),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.error,
                    side: const BorderSide(color: AppTheme.error),
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignOutDialog(
    BuildContext context,
    WidgetRef ref,
    InteractionLogger logger,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: ObservableInteraction.wrapVoidCallback(
              logger: logger,
              screenName: 'settings_screen',
              widgetName: 'sign_out_cancel_button',
              actionType: 'sign_out_cancel',
              callback: () => Navigator.of(context).pop(),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: ObservableInteraction.wrapVoidCallback(
              logger: logger,
              screenName: 'settings_screen',
              widgetName: 'sign_out_confirm_button',
              actionType: 'sign_out_confirm',
              callback: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).signOut();
              },
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}
