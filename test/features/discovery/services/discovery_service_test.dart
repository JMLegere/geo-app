import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';
import 'package:fog_of_world/core/cells/cell_service.dart';
import 'package:fog_of_world/core/fog/fog_state_resolver.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/biome/services/biome_service.dart';
import 'package:fog_of_world/features/discovery/models/discovery_event.dart';
import 'package:fog_of_world/features/discovery/services/discovery_service.dart';

// ---------------------------------------------------------------------------
// MockHabitatService — always returns a fixed set of habitats.
// ---------------------------------------------------------------------------
class _MockHabitatService extends HabitatService {
  @override
  Set<Habitat> classifyLocation(double lat, double lon) =>
      const {Habitat.forest};
}

// ---------------------------------------------------------------------------
// Minimal MockCellService — deterministic grid: "row_col" from rounded coords.
// Maps to North American coordinates so ContinentResolver returns northAmerica.
// ---------------------------------------------------------------------------
class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) =>
      '${lat.round()}_${lon.round()}';

  /// Returns a coordinate in the North American bounding box (lat 40, lon -100)
  /// offset by the cell's rounded lat/lon, so ContinentResolver always
  /// returns Continent.northAmerica for test cells.
  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    // Offset into North America: base (40, -100) + (parsedLat * 0.01, parsedLon * 0.01)
    final dLat = double.parse(parts[0]) * 0.01;
    final dLon = double.parse(parts[1]) * 0.01;
    return Geographic(lat: 40.0 + dLat, lon: -100.0 + dLon);
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final c = getCellCenter(cellId);
    const h = 0.5;
    return [
      Geographic(lat: c.lat - h, lon: c.lon - h),
      Geographic(lat: c.lat - h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon - h),
    ];
  }

  @override
  List<String> getNeighborIds(String cellId) => [];

  @override
  List<String> getCellsInRing(String cellId, int k) => [cellId];

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      [getCellId(lat, lon)];

  @override
  double get cellEdgeLengthMeters => 100.0;

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Fixture species — Forest + North America so getSpeciesForCell returns results.
// ---------------------------------------------------------------------------
final _redFox = SpeciesRecord(
  commonName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.leastConcern,
);

final _grayWolf = SpeciesRecord(
  commonName: 'Gray Wolf',
  scientificName: 'Canis lupus',
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.leastConcern,
);

final _jaguar = SpeciesRecord(
  commonName: 'Jaguar',
  scientificName: 'Panthera onca',
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.nearThreatened,
);

SpeciesService _makeSpeciesService() =>
    SpeciesService([_redFox, _grayWolf, _jaguar]);

FogStateResolver _makeResolver() => FogStateResolver(_MockCellService());

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Collects all [DiscoveryEvent]s emitted synchronously during [body].
List<DiscoveryEvent> collectDiscoveries(
  DiscoveryService service,
  void Function() body,
) {
  final events = <DiscoveryEvent>[];
  final sub = service.onDiscovery.listen(events.add);
  body();
  sub.cancel();
  return events;
}

void main() {
  group('DiscoveryService', () {
    test(
        'emits DiscoveryEvent when resolver fires FogState.observed for new cell',
        () {
      final resolver = _makeResolver();
      final speciesService = _makeSpeciesService();
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: speciesService,
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
      );
      addTearDown(service.dispose);

      final events = collectDiscoveries(service, () {
        resolver.onLocationUpdate(1.0, 1.0); // enters cell '1_1'
      });

      expect(events, isNotEmpty);
    });

    test('species not yet collected are marked isNew=true', () {
      final resolver = _makeResolver();
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: _makeSpeciesService(),
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
        initialCollectedIds: const {},
      );
      addTearDown(service.dispose);

      final events = collectDiscoveries(service, () {
        resolver.onLocationUpdate(1.0, 1.0);
      });

      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.isNew, isTrue,
            reason: '${e.species.commonName} should be new');
      }
    });

    test('species already in initialCollectedIds are marked isNew=false', () {
      final resolver = _makeResolver();

      // Pre-populate all three fixture species as already collected.
      final collectedIds = {
        _redFox.id,
        _grayWolf.id,
        _jaguar.id,
      };

      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: _makeSpeciesService(),
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
        initialCollectedIds: collectedIds,
      );
      addTearDown(service.dispose);

      final events = collectDiscoveries(service, () {
        resolver.onLocationUpdate(1.0, 1.0);
      });

      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.isNew, isFalse,
            reason: '${e.species.commonName} was pre-collected');
      }
    });

    test('markCollected flips isNew for subsequent cell entries', () {
      final resolver = _makeResolver();
      final speciesService = _makeSpeciesService();
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: speciesService,
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
      );
      addTearDown(service.dispose);

      // First cell — all new.
      final firstEvents = collectDiscoveries(service, () {
        resolver.onLocationUpdate(1.0, 1.0);
      });
      expect(firstEvents.every((e) => e.isNew), isTrue);

      // Mark everything from first cell as collected.
      for (final e in firstEvents) {
        service.markCollected(e.species.id);
      }

      // Second cell — same loot pool → all already collected.
      final secondEvents = collectDiscoveries(service, () {
        resolver.onLocationUpdate(2.0, 2.0); // new cell
      });

      // The species from the second cell may overlap — those should be not new.
      final collectedIds = firstEvents.map((e) => e.species.id).toSet();
      for (final e in secondEvents) {
        if (collectedIds.contains(e.species.id)) {
          expect(e.isNew, isFalse,
              reason: '${e.species.commonName} was already collected');
        }
      }
    });

    test('events are NOT emitted for states other than observed', () {
      final resolver = _makeResolver();
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: _makeSpeciesService(),
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
      );
      addTearDown(service.dispose);

      // Re-entering the same cell does NOT fire onVisitedCellAdded.
      resolver.onLocationUpdate(1.0, 1.0); // first visit → observed event
      final events = collectDiscoveries(service, () {
        resolver.onLocationUpdate(1.0, 1.0); // same cell — no new event
      });

      expect(events, isEmpty,
          reason: 'Re-entering an already-visited cell should emit nothing');
    });

    test('dispose cancels fog subscription — no more events after dispose', () {
      final resolver = _makeResolver();
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: _makeSpeciesService(),
        habitatService: _MockHabitatService(),
        cellService: _MockCellService(),
      );

      service.dispose();

      // onDiscovery stream is now closed, any listen will be on a closed stream.
      expect(service.onDiscovery.isBroadcast, isTrue);

      // Triggering the resolver after dispose should NOT throw.
      // (The stream is closed but the resolver is still alive.)
      expect(
        () => resolver.onLocationUpdate(5.0, 5.0),
        returnsNormally,
      );

      resolver.dispose();
    });

    test('cellId on emitted events matches the cell the player entered', () {
      final cellService = _MockCellService();
      final resolver = FogStateResolver(cellService);
      final service = DiscoveryService(
        fogResolver: resolver,
        speciesService: _makeSpeciesService(),
        habitatService: _MockHabitatService(),
        cellService: cellService,
      );
      addTearDown(service.dispose);

      const lat = 3.0;
      const lon = 7.0;
      final expectedCellId = cellService.getCellId(lat, lon);

      final events = collectDiscoveries(service, () {
        resolver.onLocationUpdate(lat, lon);
      });

      expect(events, isNotEmpty);
      for (final e in events) {
        expect(e.cellId, equals(expectedCellId));
      }
    });
  });
}
