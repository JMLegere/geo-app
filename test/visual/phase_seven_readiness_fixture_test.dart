import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/ui/product_surfaces/app/app_readiness_gate.dart';
import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/repositories/wake_lock_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/wake_lock_provider.dart';
import 'package:earth_nova/shared/debug/debug_mode_provider.dart';
import 'package:earth_nova/shared/observability/navigation/app_navigation_observer.dart';
import 'package:earth_nova/ui/product_surfaces/app/tab_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

const _readinessAssets = <String>[
  'readiness/cold-loading-390x844.png',
  'readiness/cold-loading-1440x900.png',
  'readiness/warm-hydration-390x844.png',
  'readiness/warm-hydration-1440x900.png',
  'readiness/failed-390x844.png',
  'readiness/failed-1440x900.png',
  'readiness/degraded-390x844.png',
  'readiness/degraded-1440x900.png',
  'readiness/syncing-390x844.png',
  'readiness/syncing-1440x900.png',
];

void main() {
  group('Phase seven readiness fixtures', () {
    test('declares the final 10-asset matrix', () {
      expect(_readinessAssets, hasLength(10));
      expect(_readinessAssets.toSet(), hasLength(10));
      expect(
        _readinessAssets,
        containsAll(const [
          'readiness/cold-loading-390x844.png',
          'readiness/cold-loading-1440x900.png',
          'readiness/warm-hydration-390x844.png',
          'readiness/warm-hydration-1440x900.png',
          'readiness/failed-390x844.png',
          'readiness/failed-1440x900.png',
          'readiness/degraded-390x844.png',
          'readiness/degraded-1440x900.png',
          'readiness/syncing-390x844.png',
          'readiness/syncing-1440x900.png',
        ]),
      );
    });

    testWidgets(
      'captures readiness/cold-loading-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'readiness/cold-loading-390x844.png',
        readiness: const AppReadinessState.initial(),
        prepare: _showLoadingDetails,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/cold-loading-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'readiness/cold-loading-1440x900.png',
        readiness: const AppReadinessState.initial(),
        prepare: _showLoadingDetails,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/warm-hydration-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'readiness/warm-hydration-390x844.png',
        readiness: _warmHydration,
        prepare: _showLoadingDetails,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/warm-hydration-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'readiness/warm-hydration-1440x900.png',
        readiness: _warmHydration,
        prepare: _showLoadingDetails,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/failed-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'readiness/failed-390x844.png',
        readiness: _failed,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/failed-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'readiness/failed-1440x900.png',
        readiness: _failed,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/degraded-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'readiness/degraded-390x844.png',
        readiness: _degraded,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/degraded-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'readiness/degraded-1440x900.png',
        readiness: _degraded,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/syncing-390x844.png',
      (tester) => _capture(
        tester,
        size: phaseSevenMobileSize,
        name: 'readiness/syncing-390x844.png',
        readiness: _syncing,
      ),
      skip: !phaseSevenCaptureEnabled,
    );

    testWidgets(
      'captures readiness/syncing-1440x900.png',
      (tester) => _capture(
        tester,
        size: phaseSevenDesktopSize,
        name: 'readiness/syncing-1440x900.png',
        readiness: _syncing,
      ),
      skip: !phaseSevenCaptureEnabled,
    );
  });
}

const _warmHydration = AppReadinessState(
  phase: AppReadinessPhase.hydrating,
  completedCheckpoints: {'working_set', 'pack'},
);

const _failed = AppReadinessState(
  phase: AppReadinessPhase.failed,
  completedCheckpoints: {},
  errorMessage: "Couldn't safely clear this device. Try again.",
);

const _degraded = AppReadinessState(
  phase: AppReadinessPhase.degraded,
  completedCheckpoints: AppReadinessState.requiredCheckpoints,
);

const _syncing = AppReadinessState(
  phase: AppReadinessPhase.syncing,
  completedCheckpoints: AppReadinessState.requiredCheckpoints,
);

Future<void> _capture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required AppReadinessState readiness,
  Future<void> Function(WidgetTester tester)? prepare,
}) => capturePhaseSevenFixture(
  tester,
  size: size,
  name: name,
  prepare: prepare,
  child: _readinessSurface(readiness),
);

Future<void> _showLoadingDetails(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 300));

Widget _readinessSurface(AppReadinessState readiness) {
  final observability = ObservabilityService(
    sessionId: 'phase-seven-readiness',
  );
  return ProviderScope(
    overrides: [
      appReadinessProvider.overrideWith(
        () => _StaticReadinessNotifier(readiness),
      ),
      authProvider.overrideWith(_StaticAuthNotifier.new),
      appObservabilityProvider.overrideWithValue(observability),
      wakeLockRepositoryProvider.overrideWithValue(
        _FixtureWakeLockRepository(),
      ),
      wakeLockObservabilityProvider.overrideWithValue(observability),
      navigationScreenTransitionLoggerProvider.overrideWithValue(
        NavigationScreenTransitionLogger(logEvent: (_, __, {data}) {}),
      ),
      debugModeProvider.overrideWith(_FalseDebugMode.new),
      locationProvider.overrideWith(_LoadingLocationNotifier.new),
      itemsProvider.overrideWith(_LoadedItemsNotifier.new),
      mapProvider.overrideWith(_LoadingMapNotifier.new),
      playerMarkerProvider.overrideWith(_StaticPlayerMarkerNotifier.new),
      pendingEncounterProvider.overrideWith(
        _StaticPendingEncounterNotifier.new,
      ),
      livingWorldRepositoryProvider.overrideWithValue(
        _FixtureLivingWorldRepository(),
      ),
    ],
    child: const AppReadinessGate(userId: 'fixture-user', child: TabShell()),
  );
}

class _StaticReadinessNotifier extends AppReadinessNotifier {
  _StaticReadinessNotifier(this.initial);

  final AppReadinessState initial;

  @override
  AppReadinessState build() => initial;

  @override
  Future<void> start(String userId) async {}

  @override
  Future<void> retry() async {}

  @override
  Future<bool> purge(String userId) async => true;
}

class _StaticAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.loading();

  @override
  Future<void> signOut() async {}
}

class _LoadingLocationNotifier extends LocationNotifier {
  @override
  LocationProviderState build() => const LocationProviderLoading();
}

class _LoadedItemsNotifier extends ItemsNotifier {
  @override
  ItemsState build() => const ItemsState(hasLoaded: true);
}

class _LoadingMapNotifier extends MapNotifier {
  @override
  MapState build() => const MapStateLoading();
}

class _StaticPlayerMarkerNotifier extends PlayerMarkerNotifier {
  @override
  PlayerMarkerState build() =>
      const PlayerMarkerState(lat: 0, lng: 0, isRing: false, gapDistance: 0);
}

class _StaticPendingEncounterNotifier extends PendingEncounterNotifier {
  @override
  PendingEncounterState build() => const PendingEncounterNone();
}

class _FalseDebugMode extends DebugModeNotifier {
  @override
  bool build() => false;
}

class _FixtureWakeLockRepository implements WakeLockRepository {
  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}
}

class _FixtureLivingWorldRepository implements LivingWorldRepository {
  @override
  Future<TownProjection> readTown(String playerId, {required String traceId}) =>
      Future.error(UnimplementedError());

  @override
  Future<VenueVisitResult> recordVenueVisit(
    RecordVenueVisitCommand command, {
    required String traceId,
  }) => Future.error(UnimplementedError());
}
