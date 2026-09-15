import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova_widgetbook/fixtures/auth_fixtures.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/living_world/data/repositories/mock_living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/retained_map_renderer.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/hierarchy_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_level_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:earth_nova/features/map/presentation/state/map_readiness_state.dart';
import 'package:riverpod/misc.dart';

/// Fixed Halifax cells keep every catalog frame deterministic and offline.
final class MapStoryFixtures {
  MapStoryFixtures._();

  static final location = LocationState(
    lat: 44.647,
    lng: -63.5752,
    accuracy: 4,
    timestamp: DateTime.utc(2026, 9, 15),
    isConfident: true,
  );
  static final cells = <Cell>[
    _backdropCell('halifax-informed', 44.65083, -63.58328),
    _backdropCell('halifax-present', 44.65083, -63.56712),
    _backdropCell('halifax-explored', 44.64317, -63.58328),
    _backdropCell(
      'halifax-shrouded',
      44.64317,
      -63.56712,
      districtId: 'district-north',
    ),
  ];

  static final ready = MapStateReady(
    cells: cells,
    visitedCellIds: {'halifax-present', 'halifax-explored'},
    location: location,
    knowledgeByCellId: const {
      'halifax-informed': CellKnowledgeProjection(
        cellId: 'halifax-informed',
        state: CellKnowledgeState.informed,
        category: 'flora',
      ),
    },
  );

  static List<Override> overrides({
    MapState? mapState,
    LocationProviderState? locationState,
    AuthState authState = const AuthState.unauthenticated(),
    bool paused = false,
    bool ring = false,
    MapLevel level = MapLevel.cell,
    bool hierarchyFails = false,
  }) {
    final observability = ObservabilityService(sessionId: 'widgetbook-map');
    final activeLocation =
        locationState ??
        (paused
            ? const LocationProviderPaused()
            : LocationProviderActive(location));
    return [
      appObservabilityProvider.overrideWithValue(observability),
      observableUseCaseProvider.overrideWithValue(observability),
      observabilityProvider.overrideWithValue(observability),
      mapObservabilityProvider.overrideWithValue(observability),
      locationObservabilityProvider.overrideWithValue(observability),
      explorationObservabilityProvider.overrideWithValue(observability),
      playerMarkerObservabilityProvider.overrideWithValue(observability),
      visitQueueObservabilityProvider.overrideWithValue(observability),
      encounterObservabilityProvider.overrideWithValue(observability),
      hierarchyObservabilityProvider.overrideWithValue(observability),
      mapLevelObservabilityProvider.overrideWithValue(observability),
      livingWorldObservabilityProvider.overrideWithValue(observability),
      authProvider.overrideWith(() => StoryAuthNotifier(authState)),
      mapProvider.overrideWith(() => _MapStoryMap(mapState ?? ready)),
      locationProvider.overrideWith(() => _MapStoryLocation(activeLocation)),
      playerMarkerProvider.overrideWith(() => _MapStoryMarker(ring: ring)),
      explorationProvider.overrideWith(_MapStoryExploration.new),
      encounterProvider.overrideWith(_MapStoryEncounter.new),
      pendingEncounterProvider.overrideWith(_MapStoryPendingEncounter.new),
      visitQueueProvider.overrideWith(_MapStoryVisitQueue.new),
      mapReadinessProvider.overrideWith(_MapStoryReadiness.new),
      desktopControlsAvailableProvider.overrideWithValue(false),
      desktopControlsProvider.overrideWith(_MapStoryDesktopControls.new),
      livingWorldRepositoryProvider.overrideWithValue(
        MockLivingWorldRepository(),
      ),
      hierarchyRepositoryProvider.overrideWithValue(
        _MapStoryHierarchyRepository(fails: hierarchyFails),
      ),
      mapLevelProvider.overrideWith(() => _MapStoryLevel(level)),
    ];
  }

  static Cell _backdropCell(
    String id,
    double lat,
    double lng, {
    String districtId = 'district-halifax',
  }) => _cell(id, lat, lng, districtId, latRadius: .00383, lngRadius: .00808);

  static Cell _cell(
    String id,
    double lat,
    double lng,
    String districtId, {
    double latRadius = .00028,
    double lngRadius = .00032,
  }) => Cell(
    id: id,
    habitats: const [Habitat.urban],
    polygons: [
      [
        [
          (lat: lat - latRadius, lng: lng - lngRadius),
          (lat: lat - latRadius, lng: lng + lngRadius),
          (lat: lat + latRadius, lng: lng + lngRadius),
          (lat: lat + latRadius, lng: lng - lngRadius),
          (lat: lat - latRadius, lng: lng - lngRadius),
        ],
      ],
    ],
    districtId: districtId,
    cityId: 'city-halifax',
    stateId: 'province-nova-scotia',
    countryId: 'country-canada',
    habitatConfidence: 'classified',
  );
}

/// Forces MapScreen through its production Dart painter fallback without a
/// browser renderer failure or external side effect.
class MapStoryUnavailableRetainedRenderer extends RetainedMapRenderer {
  MapStoryUnavailableRetainedRenderer() : super();

  @override
  Future<bool> attach() async => false;
}

class _MapStoryMap extends MapNotifier {
  _MapStoryMap(this.value);

  final MapState value;

  @override
  MapState build() => value;
}

class _MapStoryLocation extends LocationNotifier {
  _MapStoryLocation(this.value);

  final LocationProviderState value;

  @override
  LocationProviderState build() => value;
}

class _MapStoryMarker extends PlayerMarkerNotifier {
  _MapStoryMarker({required this.ring});

  final bool ring;

  @override
  PlayerMarkerState build() => PlayerMarkerState(
    lat: MapStoryFixtures.location.lat,
    lng: MapStoryFixtures.location.lng,
    isRing: ring,
    gapDistance: ring ? 80 : 0,
  );
}

class _MapStoryExploration extends ExplorationNotifier {
  @override
  ExplorationStateData build() => const ExplorationStateData(
    currentCellId: 'halifax-present',
    currentPositionIsTrusted: true,
    visitedCellIds: {'halifax-present'},
  );
}

class _MapStoryEncounter extends EncounterNotifier {
  @override
  EncounterState build() => const EncounterState();
}

class _MapStoryPendingEncounter extends PendingEncounterNotifier {
  @override
  PendingEncounterState build() => const PendingEncounterNone();
}

class _MapStoryVisitQueue extends VisitQueueNotifier {
  @override
  VisitQueueState build() => const VisitQueueState();
}

class _MapStoryReadiness extends MapReadinessNotifier {
  static const _ready = MapReadinessState(
    locationReady: true,
    mapCreated: true,
    styleLoaded: true,
    baseMapSettled: true,
    cellsFetched: true,
    overlayFramePainted: true,
    baseMapSettledSource: 'widgetbook_fixture',
  );

  @override
  MapReadinessState build() => _ready;

  @override
  void start() {}

  @override
  void reset() {}

  // Stories fix readiness independently of their loading/error map data.
  @override
  bool reportCellsFetched(bool isFetched) => false;

  @override
  void resetOverlayForRefetch() {}
}

class _MapStoryDesktopControls extends DesktopControlsNotifier {
  @override
  bool build() => false;
}

class _MapStoryLevel extends MapLevelNotifier {
  _MapStoryLevel(this.value);

  final MapLevel value;

  @override
  MapLevel build() => value;
}

class _MapStoryHierarchyRepository implements HierarchyRepository {
  const _MapStoryHierarchyRepository({required this.fails});

  final bool fails;

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    if (fails) throw const HierarchyRepositoryFailure.unavailable();
    return [
      HierarchyProgressSummary(
        id: '${level.name}-harbour',
        name: 'Harbour',
        level: level,
        cellsVisited: 24,
        cellsTotal: 60,
        progressPercent: 40,
        rank: 3,
      ),
      HierarchyProgressSummary(
        id: '${level.name}-north',
        name: 'North End',
        level: level,
        cellsVisited: 0,
        cellsTotal: 48,
        progressPercent: 0,
        rank: 0,
      ),
    ];
  }

  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    if (fails) throw const HierarchyRepositoryFailure.unavailable();
    return HierarchyProgressSummary(
      id: scopeId ?? level.name,
      name: switch (level) {
        MapLevel.district => 'Downtown Halifax',
        MapLevel.city => 'Halifax',
        MapLevel.state => 'Nova Scotia',
        MapLevel.country => 'Canada',
        MapLevel.world => 'World',
        MapLevel.cell => 'Map',
      },
      level: level,
      cellsVisited: 42,
      cellsTotal: 100,
      progressPercent: 42,
      rank: 3,
    );
  }
}
