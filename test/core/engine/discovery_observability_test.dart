import 'dart:convert';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/engine/game_coordinator.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/services/daily_seed_service.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/calendar/services/season_service.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/discovery/services/discovery_service.dart';
import 'package:earth_nova/features/items/services/stats_service.dart';
import 'package:earth_nova/features/world/services/biome_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import '../../fixtures/species_fixture.dart';

// ── Minimal mocks ──────────────────────────────────────────────────────────

class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) => 'v_${lat.round()}_${lon.round()}';

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    return Geographic(lat: double.parse(parts[1]), lon: double.parse(parts[2]));
  }

  @override
  List<String> getNeighborIds(String cellId) => [];

  @override
  List<Geographic> getCellBoundary(String cellId) => [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'test';
}

class _MockHabitatService extends BiomeService {
  @override
  Set<Habitat> classifyLocation(double lat, double lon) =>
      {Habitat.forest, Habitat.plains};
}

// ── Test helpers ───────────────────────────────────────────────────────────

List<String> _captureDebugPrints(void Function() body) {
  final logs = <String>[];
  final original = debugPrint;
  debugPrint = (String? msg, {int? wrapWidth}) {
    if (msg != null) logs.add(msg);
  };
  try {
    body();
  } finally {
    debugPrint = original;
  }
  return logs;
}

void main() {
  group('Discovery pipeline observability', () {
    group('FogStateResolver', () {
      test('logs [FOG] cell_entered when new cell entered', () {
        final cellService = _MockCellService();
        final resolver = FogStateResolver(cellService);

        final logs = _captureDebugPrints(() {
          resolver.onLocationUpdate(45.0, -66.0);
        });

        expect(
          logs.any((l) => l.contains('[FOG]') && l.contains('cell_entered')),
          isTrue,
          reason: 'Expected [FOG] cell_entered log, got: $logs',
        );
      });

      test('does not log [FOG] cell_entered for already-entered cell', () {
        final cellService = _MockCellService();
        final resolver = FogStateResolver(cellService);

        // Visit first time
        resolver.onLocationUpdate(45.0, -66.0);

        // Visit same cell again — no new log
        final logs = _captureDebugPrints(() {
          resolver.onLocationUpdate(45.0, -66.0);
        });

        expect(
          logs.any((l) => l.contains('[FOG]') && l.contains('cell_entered')),
          isFalse,
          reason: 'Should not log for already-entered cell',
        );
      });
    });

    group('DiscoveryService', () {
      late DiscoveryService discoveryService;
      late FogStateResolver fogResolver;
      late _MockCellService cellService;

      setUp(() {
        cellService = _MockCellService();
        fogResolver = FogStateResolver(cellService);
        discoveryService = DiscoveryService(
          fogResolver: fogResolver,
          speciesService: buildSpeciesService(),
          habitatService: _MockHabitatService(),
          cellService: cellService,
          seasonService: SeasonService(),
        );
      });

      tearDown(() {
        discoveryService.dispose();
      });

      test('logs [DISCOVERY] fog_event when fog event received', () {
        final logs = _captureDebugPrints(() {
          fogResolver.onLocationUpdate(45.0, -66.0);
        });

        expect(
          logs.any((l) => l.contains('[DISCOVERY]') && l.contains('fog_event')),
          isTrue,
          reason: 'Expected [DISCOVERY] fog_event log, got: $logs',
        );
      });

      test('logs [DISCOVERY] species_rolled for every encounter', () {
        final logs = _captureDebugPrints(() {
          fogResolver.onLocationUpdate(45.0, -66.0);
        });

        expect(
          logs.any(
              (l) => l.contains('[DISCOVERY]') && l.contains('species_rolled')),
          isTrue,
          reason: 'Expected [DISCOVERY] species_rolled log, got: $logs',
        );
      });

      test('logs [DISCOVERY] emitted for each discovery event', () {
        final events = <DiscoveryEvent>[];
        discoveryService.onDiscovery.listen(events.add);

        final logs = _captureDebugPrints(() {
          fogResolver.onLocationUpdate(45.0, -66.0);
        });

        // If species were found, should have emitted log
        if (events.isNotEmpty) {
          expect(
            logs.any((l) => l.contains('[DISCOVERY]') && l.contains('emitted')),
            isTrue,
            reason: 'Expected [DISCOVERY] emitted log, got: $logs',
          );
        }
      });

      test('logs [SEED] discovery_paused when seed is stale', () {
        final staleSeedService = DailySeedService(
          fetchRemoteSeed: () async => 'test_seed',
        );
        // Inject a stale server seed (fetched 48h ago).
        staleSeedService.cachedSeedForTest = DailySeedState(
          seed: 'old_seed',
          seedDate: '2026-01-01',
          fetchedAt: DateTime.now().subtract(const Duration(hours: 48)),
          isServerSeed: true,
        );

        // Need a fresh FogStateResolver so the new cell triggers a fog event
        final freshCellService = _MockCellService();
        final freshResolver = FogStateResolver(freshCellService);
        final svcWithStaleSeed = DiscoveryService(
          fogResolver: freshResolver,
          speciesService: buildSpeciesService(),
          habitatService: _MockHabitatService(),
          cellService: freshCellService,
          dailySeedService: staleSeedService,
        );
        addTearDown(svcWithStaleSeed.dispose);

        final logs = _captureDebugPrints(() {
          freshResolver.onLocationUpdate(46.0, -67.0);
        });

        expect(
          logs.any(
              (l) => l.contains('[SEED]') && l.contains('discovery_paused')),
          isTrue,
          reason: 'Expected [SEED] discovery_paused log, got: $logs',
        );
      });
    });

    group('DiscoveryNotifier', () {
      test('logs [DISCOVERY] toast_queued when discovery shown', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(discoveryProvider.notifier);

        final event = DiscoveryEvent(
          item: _makeFaunaDefinition('test_species'),
          cellId: 'v_45_-66',
          isNew: true,
          timestamp: DateTime.now(),
          dailySeed: 'test',
        );

        final logs = _captureDebugPrints(() {
          notifier.showDiscovery(event);
        });

        expect(
          logs.any(
              (l) => l.contains('[DISCOVERY]') && l.contains('toast_queued')),
          isTrue,
          reason: 'Expected [DISCOVERY] toast_queued log, got: $logs',
        );
      });

      test('logs [DISCOVERY] toast_overflow when queue exceeds cap', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(discoveryProvider.notifier);

        // Fill queue past cap
        final logs = _captureDebugPrints(() {
          for (var i = 0; i < kMaxNotificationQueue + 3; i++) {
            notifier.showDiscovery(DiscoveryEvent(
              item: _makeFaunaDefinition('species_$i'),
              cellId: 'v_45_-66',
              isNew: true,
              timestamp: DateTime.now(),
              dailySeed: 'test',
            ));
          }
        });

        expect(
          logs.any(
              (l) => l.contains('[DISCOVERY]') && l.contains('toast_overflow')),
          isTrue,
          reason: 'Expected [DISCOVERY] toast_overflow log, got: $logs',
        );
      });
    });

    group('GameCoordinator', () {
      test('logs [DISCOVERY] tick_skipped when cell changes during throttle',
          () {
        final cellService = _MockCellService();
        final fogResolver = FogStateResolver(cellService);
        final coordinator = GameCoordinator(
          cellService: cellService,
          fogResolver: fogResolver,
          statsService: const StatsService(),
        );

        // First call always processes — establishes _lastProcessedCellId
        coordinator.updatePlayerPosition(45.0, -66.0);

        // Second call at same cell — processed (frame 2 is not throttled
        // because interval is 6, but frame 2 IS throttled)
        // Frame 1 processed, frames 2-5 throttled, frame 6 processes
        final logs = _captureDebugPrints(() {
          // Frames 2–5: throttled, same cell — no skip log
          coordinator.updatePlayerPosition(45.0, -66.0);
          coordinator.updatePlayerPosition(45.0, -66.0);
          coordinator.updatePlayerPosition(45.0, -66.0);
          coordinator.updatePlayerPosition(45.0, -66.0);
        });

        // Same cell → no tick_skipped
        expect(
          logs.any((l) => l.contains('tick_skipped')),
          isFalse,
          reason: 'Same cell should not trigger tick_skipped',
        );

        // Now move to different cell during throttled frame
        final skipLogs = _captureDebugPrints(() {
          // Frame 6 will process, but 7 is throttled
          coordinator.updatePlayerPosition(45.0, -66.0); // frame 6 - processes
          coordinator.updatePlayerPosition(
              46.0, -67.0); // frame 7 - throttled, different cell
        });

        expect(
          skipLogs.any(
              (l) => l.contains('[DISCOVERY]') && l.contains('tick_skipped')),
          isTrue,
          reason:
              'Expected [DISCOVERY] tick_skipped when cell changes during throttle, got: $skipLogs',
        );
      });
    });
  });
}

// ── Fixture helpers ────────────────────────────────────────────────────────

FaunaDefinition _makeFaunaDefinition(String id) {
  return FaunaDefinition(
    id: id,
    scientificName: id,
    displayName: id,
    taxonomicClass: 'Mammalia',
    continents: [Continent.northAmerica],
    habitats: [Habitat.forest],
    rarity: IucnStatus.leastConcern,
  );
}

SpeciesService buildSpeciesService() {
  final raw = jsonDecode(kSpeciesFixtureJson) as List<dynamic>;
  final records = raw
      .map((j) => FaunaDefinition.fromJson(j as Map<String, dynamic>))
      .toList();
  return SpeciesService(records);
}
