import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/home/presentation/providers/home_provider.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:riverpod/misc.dart';
import 'package:earth_nova_widgetbook/fixtures/app_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/profile_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/home_fixtures.dart';
import 'package:earth_nova_widgetbook/fixtures/map_fixtures.dart';

List<Override> tabShellStoryOverrides({
  required bool debugMode,
  required bool desktopControlsAvailable,
}) {
  final observability = ObservabilityService(sessionId: 'widgetbook-tab-shell');
  return [
    ...readinessStoryOverrides(
      const AppReadinessState(
        phase: AppReadinessPhase.usable,
        completedCheckpoints: AppReadinessState.requiredCheckpoints,
      ),
    ),
    wakeLockObservabilityProvider.overrideWithValue(observability),
    wakeLockRepositoryProvider.overrideWithValue(StoryWakeLockRepository()),
    navigationScreenTransitionLoggerProvider.overrideWithValue(
      NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
    ),
    encounterProvider.overrideWith(StoryEncounterNotifier.new),
    locationProvider.overrideWith(StoryLocationNotifier.new),
    mapProvider.overrideWith(StoryMapNotifier.new),
    debugModeProvider.overrideWith(() => StoryDebugModeNotifier(debugMode)),
    desktopControlsAvailableProvider.overrideWithValue(
      desktopControlsAvailable,
    ),
    desktopControlsProvider.overrideWith(
      () => StoryDesktopControlsNotifier(enabled: false),
    ),
  ];
}

List<Override> appRootPreparingStoryOverrides() {
  final observability = ObservabilityService(sessionId: 'widgetbook-app-root');
  return [
    ...MapStoryFixtures.overrides(
      authState: AuthState.authenticated(storyHomePlayer),
      mapState: const MapStateLoading(),
      locationState: const LocationProviderLoading(),
    ),
    appReadinessProvider.overrideWith(
      () => StoryReadinessNotifier(
        const AppReadinessState(
          phase: AppReadinessPhase.hydrating,
          completedCheckpoints: {},
        ),
      ),
    ),
    homeObservabilityProvider.overrideWithValue(observability),
    homeRepositoryProvider.overrideWithValue(
      StoryHomeRepository(() async => storyHome),
    ),
    wakeLockObservabilityProvider.overrideWithValue(observability),
    wakeLockRepositoryProvider.overrideWithValue(StoryWakeLockRepository()),
    navigationScreenTransitionLoggerProvider.overrideWithValue(
      NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
    ),
    debugModeProvider.overrideWith(() => StoryDebugModeNotifier(false)),
  ];
}

List<Override> systemStoryOverrides() {
  final observability = ObservabilityService(sessionId: 'widgetbook-system');
  return [appObservabilityProvider.overrideWithValue(observability)];
}

final class StoryWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

final class StoryEncounterNotifier extends EncounterNotifier {
  @override
  EncounterState build() => const EncounterState();
}

final class StoryLocationNotifier extends LocationNotifier {
  @override
  LocationProviderState build() => const LocationProviderLoading();

  @override
  void moveDebugLocation(DebugLocationMoveDirection direction) {}

  @override
  void moveDebugLocationTo({
    required double lat,
    required double lng,
    String? targetCellId,
    String reason = 'explicit_target',
  }) {}

  @override
  void resumeGps() {}
}

final class StoryMapNotifier extends MapNotifier {
  @override
  MapState build() => const MapStateLoading();
}
