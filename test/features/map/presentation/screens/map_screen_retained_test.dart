import 'dart:async';
import 'dart:typed_data';

import 'package:earth_nova/core/domain/entities/auth_state.dart';
import 'package:earth_nova/core/domain/entities/habitat.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/pending_encounter_provider.dart';
import 'package:earth_nova/features/living_world/data/repositories/mock_living_world_repository.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/cell_overlay_painter.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/retained_map_renderer.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_eligibility_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/cell_detail_sheet.dart';
import 'package:earth_nova/ui/product_surfaces/map/widgets/desktop_traversal_input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;

final _location = LocationState(
  lat: 45,
  lng: -66,
  accuracy: 1,
  timestamp: DateTime(2026),
  isConfident: true,
);
final _cell = Cell(
  id: 'retained-cell',
  habitats: const [Habitat.forest],
  polygons: const [
    [
      [
        (lat: 44.99, lng: -66.01),
        (lat: 44.99, lng: -65.99),
        (lat: 45.01, lng: -65.99),
        (lat: 45.01, lng: -66.01),
        (lat: 44.99, lng: -66.01),
      ],
    ],
  ],
  districtId: 'd',
  cityId: 'c',
  stateId: 's',
  countryId: 'co',
);

final _cellB = Cell(
  id: 'retained-cell-b',
  habitats: const [Habitat.forest],
  polygons: const [
    [
      [
        (lat: 45.09, lng: -65.91),
        (lat: 45.09, lng: -65.89),
        (lat: 45.11, lng: -65.89),
        (lat: 45.11, lng: -65.91),
        (lat: 45.09, lng: -65.91),
      ],
    ],
  ],
  districtId: 'd',
  cityId: 'c',
  stateId: 's',
  countryId: 'co',
);

void main() {
  testWidgets(
    'retained readiness uses the camera that rendered the latest fetched scene',
    (tester) async {
      final renderer = _Renderer();
      final map = _Map();
      final container = _container(map: map);
      addTearDown(container.dispose);
      _mockMapPlatform(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: MapScreen(retainedRenderer: renderer)),
        ),
      );
      await tester.pump();
      final board = tester.widget<maplibre.MapLibreMap>(
        find.byType(maplibre.MapLibreMap),
      );
      board.onStyleLoadedCallback!();
      final readiness = container.read(mapReadinessProvider.notifier);
      readiness.reportMapCreated();
      readiness.reportBaseMapSettled(source: 'test-native-render');
      await tester.pump();

      board.onCameraMove!(
        const maplibre.CameraPosition(
          target: maplibre.LatLng(45.1, -65.9),
          zoom: 15,
        ),
      );
      map.replaceCells([_cellB]);
      await tester.pump();
      renderer.firstFrame.complete();
      await tester.pump();
      await tester.pump();

      expect(container.read(mapReadinessProvider).isSteadyStateReady, isTrue);
      expect(renderer.sceneUpdates, greaterThanOrEqualTo(2));
    },
  );

  testWidgets(
    'retained readiness stays closed after a pre-paint pan until idle returns',
    (tester) async {
      final renderer = _Renderer();
      final container = _container();
      addTearDown(container.dispose);
      _mockMapPlatform(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: MapScreen(retainedRenderer: renderer)),
        ),
      );
      await tester.pump();
      final board = tester.widget<maplibre.MapLibreMap>(
        find.byType(maplibre.MapLibreMap),
      );
      board.onStyleLoadedCallback!();
      final readiness = container.read(mapReadinessProvider.notifier);
      readiness.reportMapCreated();
      readiness.reportBaseMapSettled(source: 'test-native-render');
      await tester.pump();

      board.onCameraMove!(
        const maplibre.CameraPosition(
          target: maplibre.LatLng(45.1, -65.9),
          zoom: 15,
        ),
      );
      renderer.firstFrame.complete();
      await tester.pump();
      await tester.pump();
      expect(container.read(mapReadinessProvider).isSteadyStateReady, isFalse);
      final sceneUpdates = renderer.sceneUpdates;

      board.onCameraMove!(
        const maplibre.CameraPosition(
          target: maplibre.LatLng(45, -66),
          zoom: 15,
        ),
      );
      board.onCameraIdle!();
      await tester.pump();
      await tester.pump();

      expect(container.read(mapReadinessProvider).isSteadyStateReady, isTrue);
      expect(renderer.sceneUpdates, sceneUpdates);
    },
  );

  testWidgets(
    'retained scene owns moving marker and camera without rebuilding the board',
    (tester) async {
      final renderer = _Renderer();
      final marker = _Marker();
      final location = _Location();
      final exploration = _Exploration();
      final encounter = _Encounter();
      final obs = _Observability();
      final container = _container(
        obs: obs,
        marker: marker,
        location: location,
        exploration: exploration,
        encounter: encounter,
      );
      addTearDown(container.dispose);
      final platformCalls = _mockMapPlatform(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: MapScreen(retainedRenderer: renderer)),
        ),
      );
      await tester.pump();
      final beforeAttach = tester.widget<maplibre.MapLibreMap>(
        find.byType(maplibre.MapLibreMap),
      );
      beforeAttach.onStyleLoadedCallback!();
      final readiness = container.read(mapReadinessProvider.notifier);
      readiness.reportMapCreated();
      readiness.reportBaseMapSettled(source: 'test-native-render');
      await tester.pump();
      expect(
        container.read(mapReadinessProvider).overlayFramePainted,
        isFalse,
        reason: 'Style attachment alone is not a painted retained scene.',
      );
      renderer.onCellTap!(_cell.id);
      await tester.pump();
      expect(find.byType(CellDetailSheet), findsNothing);
      renderer.firstFrame.complete();
      await tester.pump();
      await tester.pump();
      expect(container.read(mapReadinessProvider).overlayFramePainted, isTrue);
      expect(find.byType(PlayerMarker), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CellOverlayPainter,
        ),
        findsNothing,
      );
      final board = tester.widget<maplibre.MapLibreMap>(
        find.byType(maplibre.MapLibreMap),
      );
      final sceneUpdates = renderer.sceneUpdates;
      final geometryEvents = obs.events
          .where((e) => e == 'map.geometry_rendered')
          .length;
      final projectionCalls = platformCalls
          .where((e) => e == 'map#toScreenLocationBatch')
          .length;
      for (var i = 1; i <= 5; i++) {
        marker.move(-66 + i * .00001);
        location.move(-66 + i * .00001);
        board.onCameraMove!(
          maplibre.CameraPosition(
            target: maplibre.LatLng(45, -66 + i * .00001),
            zoom: 15,
          ),
        );
        board.onCameraIdle!();
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        identical(
          board,
          tester.widget<maplibre.MapLibreMap>(
            find.byType(maplibre.MapLibreMap),
          ),
        ),
        isTrue,
      );
      expect(renderer.marker?.lng, -65.99995);
      expect(renderer.target?.lng, -65.99995);
      expect(renderer.trust, PlayerMarkerTrust.trusted);
      location.lowConfidence();
      await tester.pump();
      expect(renderer.trust, PlayerMarkerTrust.lowConfidence);
      location.pause();
      await tester.pump();
      expect(renderer.trust, PlayerMarkerTrust.paused);
      location.restore();
      await tester.pump();
      expect(renderer.trust, PlayerMarkerTrust.trusted);
      expect(renderer.sceneUpdates, sceneUpdates);
      expect(
        obs.events.where((e) => e == 'map.geometry_rendered').length,
        geometryEvents,
      );
      expect(
        platformCalls.where((e) => e == 'map#toScreenLocationBatch').length,
        projectionCalls,
      );
      expect(exploration.eligiblePositions, 5);
      marker.move(-65.99994, isRing: true);
      await tester.pump();
      expect(find.text('Discovery paused'), findsOneWidget);
      expect(exploration.eligiblePositions, 5);
      encounter.showReward();
      await tester.pump();
      renderer.onCellTap!(_cell.id);
      await tester.pump();
      expect(find.byType(CellDetailSheet), findsNothing);
      expect(
        tester
            .widget<DesktopTraversalInput>(find.byType(DesktopTraversalInput))
            .blocked,
        isTrue,
      );
      encounter.clearReward();
      await tester.pump();
      renderer.onCellTap!(_cell.id);
      await tester.pump();
      expect(find.byType(CellDetailSheet), findsOneWidget);
      expect(
        tester
            .widget<DesktopTraversalInput>(find.byType(DesktopTraversalInput))
            .blocked,
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(renderer.disposed, isTrue);
    },
  );

  testWidgets(
    'location recovery uploads unchanged scene to recreated native map',
    (tester) async {
      final renderer = _Renderer();
      final location = _Location();
      final container = _container(location: location);
      addTearDown(container.dispose);
      _mockMapPlatform(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: ShadApp(home: MapScreen(retainedRenderer: renderer)),
        ),
      );
      await tester.pump();
      tester
          .widget<maplibre.MapLibreMap>(find.byType(maplibre.MapLibreMap))
          .onStyleLoadedCallback!();
      final readiness = container.read(mapReadinessProvider.notifier);
      readiness.reportMapCreated();
      readiness.reportBaseMapSettled(source: 'first-native-map');
      await tester.pump();
      renderer.firstFrame.complete();
      await tester.pump();
      await tester.pump();
      expect(container.read(mapReadinessProvider).isSteadyStateReady, isTrue);
      final firstSceneUpdates = renderer.sceneUpdates;

      location.fail();
      await tester.pump();
      renderer.removeNativeMap();
      expect(find.byType(maplibre.MapLibreMap), findsNothing);
      expect(container.read(mapReadinessProvider).isSteadyStateReady, isFalse);
      location.restore();
      await tester.pump();
      expect(
        container.read(mapReadinessProvider).isSteadyStateReady,
        isFalse,
        reason: 'The old map frame cannot make a recreated map ready.',
      );
      tester
          .widget<maplibre.MapLibreMap>(find.byType(maplibre.MapLibreMap))
          .onStyleLoadedCallback!();
      await tester.pump();
      expect(renderer.sceneUpdates, firstSceneUpdates + 1);
      expect(container.read(mapReadinessProvider).overlayFramePainted, isFalse);
      renderer.firstFrame.complete();
      await tester.pump();
      await tester.pump();
      expect(container.read(mapReadinessProvider).isSteadyStateReady, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'native fallback keeps Flutter marker and cell overlay responsive',
    (tester) async {
      final marker = _Marker();
      final container = _container(marker: marker);
      _mockMapPlatform(tester);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(home: MapScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerMarker), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CellOverlayPainter,
        ),
        findsOneWidget,
      );
      final board = tester.widget<maplibre.MapLibreMap>(
        find.byType(maplibre.MapLibreMap),
      );
      marker.move(-65.9999);
      await tester.pump();
      expect(
        identical(
          board,
          tester.widget<maplibre.MapLibreMap>(
            find.byType(maplibre.MapLibreMap),
          ),
        ),
        isFalse,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
    },
  );

  testWidgets('failed web attachment restores responsive Flutter fallback', (
    tester,
  ) async {
    final marker = _Marker();
    final renderer = _Renderer(supported: false);
    final container = _container(marker: marker);
    _mockMapPlatform(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: ShadApp(home: MapScreen(retainedRenderer: renderer)),
      ),
    );
    await tester.pump();
    tester
        .widget<maplibre.MapLibreMap>(find.byType(maplibre.MapLibreMap))
        .onStyleLoadedCallback!();
    await tester.pump();
    expect(find.byType(PlayerMarker), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CellOverlayPainter,
      ),
      findsOneWidget,
    );
    final board = tester.widget<maplibre.MapLibreMap>(
      find.byType(maplibre.MapLibreMap),
    );
    marker.move(-65.9999);
    await tester.pump();
    expect(
      identical(
        board,
        tester.widget<maplibre.MapLibreMap>(find.byType(maplibre.MapLibreMap)),
      ),
      isFalse,
    );
    expect(renderer.sceneUpdates, 0);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    container.dispose();
  });
}

ProviderContainer _container({
  _Map? map,
  _Observability? obs,
  _Marker? marker,
  _Location? location,
  _Exploration? exploration,
  _Encounter? encounter,
}) {
  obs ??= _Observability();
  return ProviderContainer(
    overrides: [
      appObservabilityProvider.overrideWithValue(obs),
      mapObservabilityProvider.overrideWithValue(obs),
      locationObservabilityProvider.overrideWithValue(obs),
      playerMarkerObservabilityProvider.overrideWithValue(obs),
      explorationObservabilityProvider.overrideWithValue(obs),
      authProvider.overrideWith(_Auth.new),
      mapProvider.overrideWith(() => map ?? _Map()),
      locationProvider.overrideWith(() => location ?? _Location()),
      playerMarkerProvider.overrideWith(() => marker ?? _Marker()),
      encounterProvider.overrideWith(() => encounter ?? _Encounter()),
      explorationProvider.overrideWith(() => exploration ?? _Exploration()),
      pendingEncounterProvider.overrideWith(_Pending.new),
      livingWorldRepositoryProvider.overrideWithValue(
        MockLivingWorldRepository(),
      ),
      desktopControlsAvailableProvider.overrideWithValue(true),
      desktopControlsProvider.overrideWith(_DesktopControls.new),
    ],
  );
}

List<String> _mockMapPlatform(WidgetTester tester) {
  final calls = <String>[];
  final channels = <MethodChannel>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform_views,
    (call) async {
      if (call.method == 'create') {
        if (call.arguments case {'id': final int id}) {
          final channel = MethodChannel('plugins.flutter.io/maplibre_gl_$id');
          channels.add(channel);
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (call) async {
              calls.add(call.method);
              return call.method == 'map#toScreenLocationBatch'
                  ? Float64List(0)
                  : null;
            },
          );
        }
      }
      return 1;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform_views,
      null,
    );
    for (final channel in channels) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    }
  });
  return calls;
}

class _DesktopControls extends DesktopControlsNotifier {
  @override
  bool build() => true;
}

class _Encounter extends EncounterNotifier {
  void showReward() => silentTransition(
    const EncounterState(
      flyingReward: Encounter(
        type: EncounterType.species,
        speciesId: 'test',
        cellId: 'retained-cell',
        seed: 'test',
      ),
    ),
  );
  void clearReward() => silentTransition(const EncounterState());
}

class _Renderer extends RetainedMapRenderer {
  _Renderer({this.supported = true});
  final bool supported;
  var firstFrame = Completer<void>();
  bool attached = false;
  bool disposed = false;
  int sceneUpdates = 0;
  PlayerMarkerState? marker;
  PlayerMarkerTrust? trust;
  GeoCoord? target;
  void removeNativeMap() {
    attached = false;
    firstFrame = Completer<void>();
  }

  @override
  bool get isAttached => attached;
  @override
  Future<bool> attach() async => attached = supported;
  @override
  Future<void> updateScene(
    List<({Cell cell, CellState state})> entries, {
    List<Map<String, Object?>> venues = const [],
  }) async {
    sceneUpdates++;
    await firstFrame.future;
  }

  @override
  void updatePlayer(
    PlayerMarkerState value, {
    required PlayerMarkerTrust trust,
  }) {
    marker = value;
    this.trust = trust;
  }

  @override
  void updateCameraTarget(GeoCoord value) => target = value;
  @override
  void dispose() {
    disposed = true;
    attached = false;
  }
}

class _Auth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.unauthenticated();
}

class _Map extends MapNotifier {
  List<Cell> _cells = [_cell];

  @override
  MapState build() => MapStateReady(
    cells: _cells,
    visitedCellIds: {_cell.id},
    location: _location,
  );

  void replaceCells(List<Cell> cells) {
    _cells = cells;
    silentTransition(
      MapStateReady(
        cells: cells,
        visitedCellIds: cells.map((cell) => cell.id).toSet(),
        location: _location,
      ),
    );
  }
}

class _Pending extends PendingEncounterNotifier {
  @override
  PendingEncounterState build() => const PendingEncounterNone();
}

class _Location extends LocationNotifier {
  @override
  LocationProviderState build() => LocationProviderActive(_location);

  void fail() =>
      silentTransition(const LocationProviderError('GPS unavailable'));

  void restore() => silentTransition(LocationProviderActive(_location));

  void move(double lng) => silentTransition(
    LocationProviderActive(
      LocationState(
        lat: 45,
        lng: lng,
        accuracy: 1,
        timestamp: DateTime(2026),
        isConfident: true,
      ),
    ),
  );

  void lowConfidence() => silentTransition(
    LocationProviderActive(
      LocationState(
        lat: _location.lat,
        lng: _location.lng,
        accuracy: _location.accuracy,
        timestamp: _location.timestamp,
        isConfident: false,
      ),
    ),
  );

  void pause() => silentTransition(const LocationProviderPaused());
}

class _Marker extends PlayerMarkerNotifier {
  @override
  PlayerMarkerState build() =>
      const PlayerMarkerState(lat: 45, lng: -66, isRing: false, gapDistance: 0);

  void move(double lng, {bool isRing = false}) => silentTransition(
    PlayerMarkerState(lat: 45, lng: lng, isRing: isRing, gapDistance: 1),
  );
}

class _Exploration extends ExplorationNotifier {
  int eligiblePositions = 0;
  @override
  ExplorationStateData build() => ExplorationStateData(
    currentCellId: _cell.id,
    currentPositionIsTrusted: true,
  );
  @override
  Future<void> onPositionUpdate({
    required PlayerMarkerState markerState,
    required List<Cell> cells,
    required Set<String> visitedCellIds,
    Map<String, CellKnowledgeProjection> knowledgeByCellId = const {},
    String? userId,
    ExplorationEligibility? explorationEligibility,
  }) async {
    if (explorationEligibility?.canRecordVisits == true) eligiblePositions++;
  }
}

class _Observability extends ObservabilityService {
  _Observability() : super(sessionId: 'retained-map-screen-test');
  final events = <String>[];
  @override
  void log(String event, String category, {Map<String, dynamic>? data}) =>
      events.add(event);
}
