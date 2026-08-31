import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:earth_nova/shared/observability/widgets/observable_interaction.dart';
import 'package:earth_nova/shared/observability/widgets/observable_screen.dart';

/// Settings screen — sign out only in v3 MVP.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktopControlsAvailable = ref.watch(
      desktopControlsAvailableProvider,
    );
    final desktopControlsEnabled = ref.watch(desktopControlsProvider);
    final obs = ref.watch(appObservabilityProvider);
    final debugMode = ref.watch(debugModeProvider);
    const executionEnvironment = String.fromEnvironment(
      'DEPLOYMENT_ENVIRONMENT',
      defaultValue: 'unknown',
    );
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
        appBar: AppBar(title: const Text('Settings')),
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth < 640
                      ? constraints.maxWidth
                      : 640,
                ),
                child: SizedBox(
                  key: const Key('settings_content'),
                  width: double.infinity,
                  child: AppCard(
                    title: 'Explorer',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: MergeSemantics(
                            key: const Key('debug_mode_semantics'),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 44),
                              child: SizedBox(
                                width: double.infinity,
                                child: ShadSwitch(
                                  key: const Key('debug_mode_toggle'),
                                  value: debugMode,
                                  label: const Text('Developer Mode'),
                                  sublabel: const Text('Debug controls'),
                                  onChanged:
                                      ObservableInteraction.wrapValueChanged<
                                        bool
                                      >(
                                        logger: logger,
                                        screenName: 'settings_screen',
                                        widgetName: 'debug_mode_toggle',
                                        actionType: 'toggle_debug_mode',
                                        payloadBuilder: (enabled) => {
                                          'enabled': enabled,
                                        },
                                        telemetryOnlyReason:
                                            'Developer mode toggle is debug chrome outside the SuperBDD gameplay action catalog.',
                                        callback: (_) => ref
                                            .read(debugModeProvider.notifier)
                                            .toggle(),
                                      ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppFieldRow(
                          key: const Key('execution_environment'),
                          label: 'Execution Environment',
                          value: '$executionEnvironment client · prod data',
                        ),
                        if (desktopControlsAvailable)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: MergeSemantics(
                              key: const Key('desktop_controls_semantics'),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ShadSwitch(
                                    key: const Key('desktop_controls_toggle'),
                                    value: desktopControlsEnabled,
                                    label: const Text('Desktop Controls'),
                                    sublabel: const Text(
                                      'Enable Desktop Traversal input',
                                    ),
                                    onChanged:
                                        ObservableInteraction.wrapValueChanged<
                                          bool
                                        >(
                                          logger: logger,
                                          screenName: 'settings_screen',
                                          widgetName: 'desktop_controls_toggle',
                                          actionType: 'toggle_desktop_controls',
                                          payloadBuilder: (enabled) => {
                                            'enabled': enabled,
                                          },
                                          telemetryOnlyReason:
                                              'Desktop Controls toggle is input chrome outside the SuperBDD gameplay action catalog.',
                                          callback: (enabled) => ref
                                              .read(
                                                desktopControlsProvider
                                                    .notifier,
                                              )
                                              .setEnabled(enabled),
                                        ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        AppButton(
                          key: const Key('sign_out_button'),
                          label: 'Sign Out',
                          variant: AppButtonVariant.destructive,
                          expand: true,
                          onPressed: ObservableInteraction.wrapVoidCallback(
                            logger: logger,
                            screenName: 'settings_screen',
                            widgetName: 'sign_out_button',
                            actionType: 'open_sign_out_dialog',
                            telemetryOnlyReason:
                                'Sign-out dialog entry is account chrome outside the SuperBDD gameplay action catalog.',
                            callback: () => _showSignOutDialog(context, ref),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

    showShadDialog<void>(
      context: context,
      builder: (context) => ShadDialog.alert(
        title: const Text('Sign Out'),
        description: const Text('Are you sure you want to sign out?'),
        actions: [
          AppButton(
            key: const Key('sign_out_dialog_cancel'),
            label: 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: ObservableInteraction.wrapVoidCallback(
              logger: logger,
              screenName: 'settings_screen',
              widgetName: 'sign_out_dialog_cancel',
              actionType: 'cancel_sign_out',
              telemetryOnlyReason:
                  'Sign-out cancellation is account chrome outside the SuperBDD gameplay action catalog.',
              callback: () => Navigator.of(context).pop(),
            ),
          ),
          AppButton(
            key: const Key('sign_out_dialog_confirm'),
            label: 'Sign Out',
            variant: AppButtonVariant.destructive,
            onPressed: ObservableInteraction.wrapVoidCallback(
              logger: logger,
              screenName: 'settings_screen',
              widgetName: 'sign_out_dialog_confirm',
              actionType: 'confirm_sign_out',
              telemetryOnlyReason:
                  'Sign-out confirmation is account chrome outside the SuperBDD gameplay action catalog.',
              callback: () {
                Navigator.of(context).pop();
                ref.read(authProvider.notifier).signOut();
              },
            ),
          ),
        ],
      ),
    );
  }
}
