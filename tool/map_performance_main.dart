// @dart=3.3
// Build: flutter build web --release --target tool/map_performance_main.dart
// Serve build/web on loopback; use map_performance_browser.mjs request blocking.
// This entrypoint never initializes Supabase or binds an external telemetry sink.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:earth_nova/app/readiness/app_readiness.dart';
import 'package:earth_nova/app/readiness/pack_media_readiness.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/core/observability/app_observability_provider.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/observable_use_case_provider.dart';
import 'package:earth_nova/core/persistence/shared_preferences_provider.dart';
import 'package:earth_nova/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:earth_nova/features/auth/presentation/providers/auth_provider.dart';
import 'package:earth_nova/features/encounters/presentation/providers/encounter_entry_provider.dart';
import 'package:earth_nova/features/identification/data/repositories/mock_item_repository.dart';
import 'package:earth_nova/features/identification/presentation/providers/items_provider.dart';
import 'package:earth_nova/features/living_world/data/repositories/mock_living_world_repository.dart';
import 'package:earth_nova/features/living_world/domain/entities/town_projection.dart';
import 'package:earth_nova/features/living_world/presentation/providers/town_provider.dart';
import 'package:earth_nova/features/map/data/repositories/mock_location_repository.dart';
import 'package:earth_nova/features/map/presentation/providers/desktop_controls_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/encounter_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/exploration_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/location_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/map_readiness_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/player_marker_provider.dart';
import 'package:earth_nova/features/map/presentation/providers/visit_queue_provider.dart';
import 'package:earth_nova/ui/product_surfaces/map/screens/map_screen.dart';
import 'package:earth_nova/features/pack/data/repositories/legacy_item_repository_pack_adapter.dart';
import 'package:earth_nova/ui/design_system.dart';

import 'map_performance_fixture.dart';

@JS('earthNovaMapFixture')
external set _bridge(_FixtureBridge value);

extension type _FixtureBridge._(JSObject _) implements JSObject {
  external factory _FixtureBridge({
    required JSFunction snapshot,
    required JSFunction pause,
    required JSFunction resume,
    required JSFunction resetPosition,
    required JSFunction moveToCell,
  });
}

// Local fixture actions only. Inherits real Desktop Traversal and its canonical
// position updates; suspension exercises real screen/eligibility pause handling.
class _FixtureLocationNotifier extends LocationNotifier {
  LocationProviderActive? _beforePause;

  void pause() {
    if (state case final LocationProviderActive active) {
      _beforePause = active;
      transition(const LocationProviderPaused(), 'fixture.position_paused');
    }
  }

  void resume() {
    final previous = _beforePause;
    if (previous == null) return;
    _beforePause = null;
    transition(previous, 'fixture.position_resumed');
  }
}

/// The fixture deliberately has no Pack media and therefore no image transport.
class _FixturePackMediaReadiness implements PackMediaReadiness {
  const _FixturePackMediaReadiness();

  @override
  Future<PackMediaPreparation> prepare(List<Item> _) async =>
      const PackMediaPreparation(requested: 0, decoded: 0, fallbacks: 0);
}

Future<void> main() async {
  if (!{'localhost', '127.0.0.1', '::1'}.contains(Uri.base.host)) {
    throw StateError('Map performance fixture is loopback-only.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final fixture = MapPerformanceFixture();
  await fixture.seedVisits();
  final auth = MockAuthRepository();
  await auth.signInWithEmail('0000000605@example.invalid', 'fixture-only');
  final items = MockItemRepository();
  final obs = ObservabilityService(sessionId: 'local-map-performance-605');
  obs.startPeriodicFlush(); // No client: drops local buffers, never exports.
  // Replaces the persistence plugin with its existing in-memory implementation.
  // This is a test fixture entrypoint, not application persistence.
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'desktop_player_position.${obs.deploymentEnvironment}.${fixture.userId}.lat':
        fixture.start.lat,
    'desktop_player_position.${obs.deploymentEnvironment}.${fixture.userId}.lng':
        fixture.start.lng,
  });
  final preferences = await SharedPreferences.getInstance();
  final location = _FixtureLocationNotifier();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(preferences),
    authRepositoryProvider.overrideWithValue(auth),
    nullableSupabaseClientProvider.overrideWithValue(null),
    observabilityProvider.overrideWithValue(obs),
    appObservabilityProvider.overrideWithValue(obs),
    observableUseCaseProvider.overrideWithValue(obs),
    itemRepositoryProvider.overrideWithValue(items),
    packRepositoryProvider
        .overrideWithValue(LegacyItemRepositoryPackAdapter(items)),
    itemsObservabilityProvider.overrideWithValue(obs),
    packMediaReadinessProvider
        .overrideWithValue(const _FixturePackMediaReadiness()),
    livingWorldRepositoryProvider.overrideWithValue(MockLivingWorldRepository(
      town: TownProjection(playerId: fixture.userId),
    )),
    livingWorldObservabilityProvider.overrideWithValue(obs),
    cellRepositoryProvider.overrideWithValue(fixture.repository),
    cellKnowledgeRepositoryProvider.overrideWithValue(fixture),
    locationRepositoryProvider.overrideWithValue(MockLocationRepository()),
    locationProvider.overrideWith(() => location),
    desktopControlsAvailableProvider.overrideWithValue(true),
    mapObservabilityProvider.overrideWithValue(obs),
    locationObservabilityProvider.overrideWithValue(obs),
    encounterObservabilityProvider.overrideWithValue(obs),
    explorationObservabilityProvider.overrideWithValue(obs),
    playerMarkerObservabilityProvider.overrideWithValue(obs),
    visitQueueObservabilityProvider.overrideWithValue(obs),
    appReadinessEnvironmentProvider.overrideWithValue('fixture'),
    encounterNowProvider.overrideWithValue(DateTime.utc(2026, 9, 11)),
  ]);
  await container.read(authProvider.notifier).restoreSession();
  container.read(desktopControlsProvider.notifier).setEnabled(true);
  _bridge = _FixtureBridge(
    snapshot: (() {
      final marker = container.read(playerMarkerProvider);
      final exploration = container.read(explorationProvider);
      return jsonEncode({
        'cellCount': fixture.cells.length,
        'generationMode': 'shared_vertex_warped_hex',
        'readiness': container.read(appReadinessProvider).phase.name,
        'mapReadiness': container.read(mapReadinessProvider).toLogData(),
        'currentCellId': exploration.currentCellId,
        'currentPositionIsTrusted': exploration.currentPositionIsTrusted,
        'marker': {
          'lat': marker.lat,
          'lng': marker.lng,
          'isRing': marker.isRing
        },
        'paused': container.read(locationProvider) is LocationProviderPaused,
        'visitedCellIds': {
          ...fixture.exploredCellIds,
          ...exploration.visitedCellIds
        }.toList(),
        'informedCellIds': fixture.knowledgeByCellId.keys.toList(),
      });
    }).toJS,
    pause: location.pause.toJS,
    resume: location.resume.toJS,
    resetPosition: (() {
      location.resume();
      location.moveDebugLocationTo(
          lat: fixture.start.lat,
          lng: fixture.start.lng,
          reason: 'fixture_reset');
    }).toJS,
    moveToCell: ((String cellId) {
      final cell = fixture.cells.firstWhere((cell) => cell.id == cellId);
      final ring = cell.primaryExteriorRing;
      location.resume();
      location.moveDebugLocationTo(
        lat: ring.fold(0.0, (sum, point) => sum + point.lat) / ring.length,
        lng: ring.fold(0.0, (sum, point) => sum + point.lng) / ring.length,
        targetCellId: cellId,
        reason: 'fixture_cell_target',
      );
    }).toJS,
  );
  runApp(UncontrolledProviderScope(
    container: container,
    child: ShadApp.custom(
      theme: AppDesignTheme.dark(),
      themeMode: ThemeMode.dark,
      appBuilder: (context) => MaterialApp(
        title: 'EarthNova local map performance fixture',
        debugShowCheckedModeBanner: false,
        theme: Theme.of(context),
        home: const MapScreen(),
      ),
    ),
  ));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(
        container.read(appReadinessProvider.notifier).start(fixture.userId));
  });
}
