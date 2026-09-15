import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/domain/entities/user_profile.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/living_world/domain/entities/living_world_knowledge.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/domain/repositories/living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/domain/entities/camera_follow_state.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/camera_follow_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/city_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/country_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/district_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/province_screen.dart';
import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/map_status_bar.dart';
import 'package:earth_nova/ui/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'phase_seven_capture_support.dart';

const _mapAssets = <String>[
  'map/bootstrap-390x844.png',
  'map/bootstrap-1440x900.png',
  'map/paused-degraded-retained-context-390x844.png',
  'map/paused-degraded-retained-context-1440x900.png',
  'map/permission-denied-390x844.png',
  'map/permission-denied-1440x900.png',
  'map/gps-unavailable-390x844.png',
  'map/gps-unavailable-1440x900.png',
  'map/unavailable-390x844.png',
  'map/unavailable-1440x900.png',
  'hierarchy/district-current-390x844.png',
  'hierarchy/district-current-1440x900.png',
  'hierarchy/city-current-390x844.png',
  'hierarchy/city-current-1440x900.png',
  'hierarchy/state-current-390x844.png',
  'hierarchy/state-current-1440x900.png',
  'hierarchy/country-current-390x844.png',
  'hierarchy/country-current-1440x900.png',
];

const _bootstrapReadiness = MapReadinessState(
  locationReady: true,
  mapCreated: true,
  styleLoaded: false,
  baseMapSettled: false,
  cellsFetched: true,
  overlayFramePainted: false,
);

final _retainedMap = MapStateRefreshing(
  previous: MapStateReady(
    cells: const [],
    visitedCellIds: const {'visited-cell'},
    location: LocationState(
      lat: 45.9636,
      lng: -66.6431,
      accuracy: 8,
      timestamp: DateTime.utc(2026),
      isConfident: false,
    ),
  ),
  refreshLocation: LocationState(
    lat: 45.9636,
    lng: -66.6431,
    accuracy: 0,
    timestamp: DateTime.utc(2026),
    isConfident: false,
  ),
);

void main() {
  group('Phase seven map state fixtures', () {
    test('declares the final 18-asset map matrix', () {
      expect(_mapAssets, hasLength(18));
      expect(_mapAssets.toSet(), hasLength(18));
      expect(
        _mapAssets,
        containsAll(const [
          'map/bootstrap-390x844.png',
          'map/bootstrap-1440x900.png',
          'map/paused-degraded-retained-context-390x844.png',
          'map/paused-degraded-retained-context-1440x900.png',
          'map/permission-denied-390x844.png',
          'map/permission-denied-1440x900.png',
          'map/gps-unavailable-390x844.png',
          'map/gps-unavailable-1440x900.png',
          'map/unavailable-390x844.png',
          'map/unavailable-1440x900.png',
          'hierarchy/district-current-390x844.png',
          'hierarchy/district-current-1440x900.png',
          'hierarchy/city-current-390x844.png',
          'hierarchy/city-current-1440x900.png',
          'hierarchy/state-current-390x844.png',
          'hierarchy/state-current-1440x900.png',
          'hierarchy/country-current-390x844.png',
          'hierarchy/country-current-1440x900.png',
        ]),
      );
    });

    for (final viewport in const [
      (size: phaseSevenMobileSize, suffix: '390x844'),
      (size: phaseSevenDesktopSize, suffix: '1440x900'),
    ]) {
      testWidgets(
        'captures map/bootstrap-${viewport.suffix}.png',
        (tester) => _capture(
          tester,
          size: viewport.size,
          name: 'map/bootstrap-${viewport.suffix}.png',
          child: const _MapBootstrapSurface(readiness: _bootstrapReadiness),
          prepare: (tester) async {
            expect(_bootstrapReadiness.isSteadyStateReady, isFalse);
            expect(_bootstrapReadiness.waitingFor, contains('style_loaded'));
            expect(
              find.byKey(const ValueKey('map-readiness-cover')),
              findsOneWidget,
            );
          },
        ),
        skip: !phaseSevenCaptureEnabled,
      );

      testWidgets(
        'captures map/paused-degraded-retained-context-${viewport.suffix}.png',
        (tester) => _capture(
          tester,
          size: viewport.size,
          name: 'map/paused-degraded-retained-context-${viewport.suffix}.png',
          child: const _PausedRetainedContextSurface(),
          prepare: (tester) async {
            expect(_retainedMap, isA<MapStateRefreshing>());
            expect(
              const LocationProviderPaused(),
              isA<LocationProviderPaused>(),
            );
            expect(
              find.byKey(const ValueKey('discovery-paused-status')),
              findsOneWidget,
            );
            expect(find.byType(MapStatusBar), findsOneWidget);
          },
        ),
        skip: !phaseSevenCaptureEnabled,
      );

      for (final failure in const [
        (
          name: 'permission-denied',
          location: LocationProviderPermissionDenied(),
          expected: 'Location needed',
        ),
        (
          name: 'gps-unavailable',
          location: LocationProviderPaused(),
          expected: 'GPS unavailable',
        ),
        (
          name: 'unavailable',
          location: LocationProviderError('Offline map data could not load.'),
          expected: 'Map unavailable',
        ),
      ]) {
        testWidgets(
          'captures map/${failure.name}-${viewport.suffix}.png',
          (tester) => _capture(
            tester,
            size: viewport.size,
            name: 'map/${failure.name}-${viewport.suffix}.png',
            child: _mapStatusSurface(failure.location),
            prepare: (tester) async {
              expect(failure.location, isA<LocationProviderState>());
              expect(find.text(failure.expected), findsOneWidget);
              expect(find.byType(MapScreen), findsOneWidget);
            },
          ),
          skip: !phaseSevenCaptureEnabled,
        );
      }

      for (final hierarchy in _hierarchyScenes) {
        testWidgets(
          'captures hierarchy/${hierarchy.name}-current-${viewport.suffix}.png',
          (tester) => _capture(
            tester,
            size: viewport.size,
            name: 'hierarchy/${hierarchy.name}-current-${viewport.suffix}.png',
            child: _hierarchySurface(hierarchy.child),
            prepare: (tester) async {
              await tester.pump();
              expect(find.text(hierarchy.level), findsWidgets);
              expect(find.text(hierarchy.scopeName), findsOneWidget);
            },
          ),
          skip: !phaseSevenCaptureEnabled,
        );
      }
    }
  });
}

Future<void> _capture(
  WidgetTester tester, {
  required Size size,
  required String name,
  required Widget child,
  required Future<void> Function(WidgetTester tester) prepare,
}) => capturePhaseSevenFixture(
  tester,
  size: size,
  name: name,
  child: child,
  prepare: prepare,
);

Widget _mapStatusSurface(LocationProviderState location) {
  final observability = ObservabilityService(
    sessionId: 'phase-seven-map-state',
  );
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      authProvider.overrideWith(_LoadingAuthNotifier.new),
      locationProvider.overrideWith(() => _StaticLocationNotifier(location)),
      mapProvider.overrideWith(_StaticMapNotifier.new),
      mapReadinessProvider.overrideWith(_StaticMapReadinessNotifier.new),
      cameraFollowProvider.overrideWith(_StaticCameraFollowNotifier.new),
      playerMarkerProvider.overrideWith(_StaticPlayerMarkerNotifier.new),
      explorationProvider.overrideWith(_StaticExplorationNotifier.new),
      encounterProvider.overrideWith(_StaticEncounterNotifier.new),
      livingWorldRepositoryProvider.overrideWithValue(
        _FixtureLivingWorldRepository(),
      ),
      livingWorldObservabilityProvider.overrideWithValue(observability),
    ],
    child: const MapScreen(),
  );
}

Widget _hierarchySurface(Widget child) {
  final observability = ObservabilityService(
    sessionId: 'phase-seven-hierarchy',
  );
  return ProviderScope(
    overrides: [
      appObservabilityProvider.overrideWithValue(observability),
      authProvider.overrideWith(_FixtureAuthNotifier.new),
      hierarchyRepositoryProvider.overrideWithValue(
        _FixtureHierarchyRepository(),
      ),
      hierarchyObservabilityProvider.overrideWithValue(observability),
    ],
    child: Scaffold(body: child),
  );
}

class _MapBootstrapSurface extends StatelessWidget {
  const _MapBootstrapSurface({required this.readiness});

  final MapReadinessState readiness;

  @override
  Widget build(BuildContext context) {
    final waitingText =
        'Revealing map... ${readiness.waitingFor.first.replaceAll('_', ' ')}';
    return _NeutralSemanticMapHost(
      child: Semantics(
        key: const ValueKey('map-readiness-cover'),
        container: true,
        liveRegion: true,
        label: waitingText,
        child: ExcludeSemantics(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: AppCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LoadingDots(),
                    const SizedBox(height: Spacing.lg),
                    Text(waitingText, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PausedRetainedContextSurface extends StatelessWidget {
  const _PausedRetainedContextSurface();

  @override
  Widget build(BuildContext context) {
    return _NeutralSemanticMapHost(
      child: const Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: MapStatusBar(cellsObserved: 1, totalSteps: 0, streakDays: 0),
          ),
          Positioned(
            top: 112,
            left: Spacing.lg,
            right: Spacing.giant,
            child: IgnorePointer(child: DiscoveryPausedBanner()),
          ),
          Positioned(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: Spacing.huge,
            child: IgnorePointer(child: MapCellKnowledgeLegend()),
          ),
        ],
      ),
    );
  }
}

class _NeutralSemanticMapHost extends StatelessWidget {
  const _NeutralSemanticMapHost({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(fit: StackFit.expand, children: [child]),
      ),
    );
  }
}

const _fixtureDistrictBoundary = DistrictBoundary(
  polygons: [
    [
      [
        (lat: 45.9624, lng: -66.6450),
        (lat: 45.9624, lng: -66.6428),
        (lat: 45.9642, lng: -66.6428),
        (lat: 45.9642, lng: -66.6450),
        (lat: 45.9624, lng: -66.6450),
      ],
    ],
  ],
);

final _hierarchyScenes =
    <({String name, String level, String scopeName, Widget child})>[
      (
        name: 'district',
        level: 'District',
        scopeName: 'Fixture District',
        child: DistrictScreen(
          scopeId: 'district-fixture',
          cells: [_fixtureCell],
          visitedCellIds: const {'fixture-cell'},
          currentCellId: 'fixture-cell',
        ),
      ),
      (
        name: 'city',
        level: 'City',
        scopeName: 'Fixture City',
        child: const CityScreen(scopeId: 'city-fixture'),
      ),
      (
        name: 'state',
        level: 'State',
        scopeName: 'Fixture State',
        child: const ProvinceScreen(scopeId: 'state-fixture'),
      ),
      (
        name: 'country',
        level: 'Country',
        scopeName: 'Fixture Country',
        child: const CountryScreen(scopeId: 'country-fixture'),
      ),
    ];

final _fixtureCell = Cell(
  id: 'fixture-cell',
  habitats: const [Habitat.urban],
  polygons: [
    [
      const [
        (lat: 45.9628, lng: -66.6444),
        (lat: 45.9627, lng: -66.6436),
        (lat: 45.9633, lng: -66.6432),
        (lat: 45.9639, lng: -66.6438),
        (lat: 45.9635, lng: -66.6446),
        (lat: 45.9628, lng: -66.6444),
      ],
    ],
  ],
  districtId: 'district-fixture',
  cityId: 'city-fixture',
  stateId: 'state-fixture',
  countryId: 'country-fixture',
  habitatConfidence: 'classified',
);

class _LoadingAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState.loading();

  @override
  Future<void> signOut() async {}
}

class _FixtureAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(
    UserProfile(
      id: 'fixture-user',
      phone: '5551234567',
      createdAt: DateTime(2026),
    ),
  );

  @override
  Future<void> signOut() async {}
}

class _StaticLocationNotifier extends LocationNotifier {
  _StaticLocationNotifier(this.initial);

  final LocationProviderState initial;

  @override
  LocationProviderState build() => initial;
}

class _StaticMapNotifier extends MapNotifier {
  @override
  MapState build() => const MapStateLoading();
}

class _StaticMapReadinessNotifier extends MapReadinessNotifier {
  @override
  MapReadinessState build() => const MapReadinessState.initial();
}

class _StaticCameraFollowNotifier extends CameraFollowNotifier {
  @override
  CameraFollowState build() => const CameraFollowState.noFix();
}

class _StaticPlayerMarkerNotifier extends PlayerMarkerNotifier {
  @override
  PlayerMarkerState build() =>
      const PlayerMarkerState(lat: 0, lng: 0, isRing: false, gapDistance: 0);
}

class _StaticExplorationNotifier extends ExplorationNotifier {
  @override
  ExplorationStateData build() => const ExplorationStateData();
}

class _StaticEncounterNotifier extends EncounterNotifier {
  @override
  EncounterState build() => const EncounterState();
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

class _FixtureHierarchyRepository implements HierarchyRepository {
  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async => HierarchyProgressSummary(
    id: scopeId ?? 'world-fixture',
    name: 'Fixture ${_labelFor(level)}',
    level: level,
    cellsVisited: 42,
    cellsTotal: 100,
    progressPercent: 42,
    rank: 3,
    districtBoundary: level == MapLevel.district
        ? _fixtureDistrictBoundary
        : null,
  );

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async => [
    HierarchyProgressSummary(
      id: '${level.name}-child-a',
      name: 'North',
      level: level,
      cellsVisited: 12,
      cellsTotal: 40,
      progressPercent: 30,
      rank: 1,
    ),
    HierarchyProgressSummary(
      id: '${level.name}-child-b',
      name: 'South',
      level: level,
      cellsVisited: 28,
      cellsTotal: 40,
      progressPercent: 70,
      rank: 2,
    ),
  ];

  String _labelFor(MapLevel level) => switch (level) {
    MapLevel.district => 'District',
    MapLevel.city => 'City',
    MapLevel.state => 'State',
    MapLevel.country => 'Country',
    MapLevel.world => 'World',
    MapLevel.cell => 'Map',
  };
}
