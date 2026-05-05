import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

/// Settings screen — sign out only in v3 MVP.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final debugMode = ref.watch(debugModeProvider);
    final obs = ref.watch(appObservabilityProvider);
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      obs.log(event, category, data: data);
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
                SwitchListTile(
                  key: const Key('debug_mode_toggle'),
                  title: const Text('Developer Mode'),
                  subtitle: const Text('Debug controls'),
                  value: debugMode,
                  onChanged: ObservableInteraction.wrapValueChanged<bool>(
                    logger: logger,
                    screenName: 'settings_screen',
                    widgetName: 'debug_mode_toggle',
                    actionType: 'toggle_debug_mode',
                    payloadBuilder: (enabled) => {'enabled': enabled},
                    callback: (_) =>
                        ref.read(debugModeProvider.notifier).toggle(),
                  ),
                ),
                const SizedBox(height: Spacing.md),
                OutlinedButton(
                  onPressed: ObservableInteraction.wrapVoidCallback(
                    logger: logger,
                    screenName: 'settings_screen',
                    widgetName: 'sign_out_button',
                    actionType: 'open_sign_out_dialog',
                    callback: () => _showSignOutDialog(context, ref),
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

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final obs = ref.read(appObservabilityProvider);
    void logger({
      required String event,
      required String category,
      Map<String, dynamic>? data,
    }) {
      obs.log(event, category, data: data);
    }

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
              widgetName: 'sign_out_dialog_cancel',
              actionType: 'cancel_sign_out',
              callback: () => Navigator.of(context).pop(),
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: ObservableInteraction.wrapVoidCallback(
              logger: logger,
              screenName: 'settings_screen',
              widgetName: 'sign_out_dialog_confirm',
              actionType: 'confirm_sign_out',
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
