import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_notifier.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';

const _desktopControlsDefault =
    bool.fromEnvironment('DESKTOP_CONTROLS_DEFAULT');
const _deploymentEnvironment = String.fromEnvironment(
  'DEPLOYMENT_ENVIRONMENT',
  defaultValue: 'unknown',
);

bool desktopControlsAvailableFor({
  required bool buildEnabled,
  required bool isWeb,
  required TargetPlatform platform,
}) =>
    buildEnabled &&
    isWeb &&
    switch (platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows =>
        true,
      _ => false,
    };

final desktopControlsAvailableProvider = Provider<bool>(
  (ref) => desktopControlsAvailableFor(
    buildEnabled: const bool.fromEnvironment('DESKTOP_CONTROLS_AVAILABLE'),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  ),
);

final desktopControlsProvider = NotifierProvider<DesktopControlsNotifier, bool>(
  DesktopControlsNotifier.new,
);

class DesktopControlsNotifier extends ObservableNotifier<bool> {
  @override
  ObservabilityService get obs => ref.watch(appObservabilityProvider);

  @override
  String get category => 'desktop_controls';

  @override
  bool build() {
    if (!ref.watch(desktopControlsAvailableProvider)) return false;

    final auth = ref.watch(authProvider);
    if (auth.status != AuthStatus.authenticated) return false;

    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_preferenceKey(auth.user!.id)) ??
        _desktopControlsDefault;
  }

  void setEnabled(bool enabled) {
    if (!ref.read(desktopControlsAvailableProvider)) return;

    final auth = ref.read(authProvider);
    if (auth.status != AuthStatus.authenticated) return;

    ref
        .read(sharedPreferencesProvider)
        .setBool(_preferenceKey(auth.user!.id), enabled);
    transition(
      enabled,
      'desktop_controls.set_enabled',
      data: {'enabled': enabled},
    );
  }

  void toggle() => setEnabled(!state);

  String _preferenceKey(String userId) =>
      'desktop_controls_enabled.$_deploymentEnvironment.$userId';
}
