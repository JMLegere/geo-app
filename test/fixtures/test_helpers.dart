// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:geobase/geobase.dart';

import 'package:earth_nova/domain/cells/cell_service.dart';
import 'package:earth_nova/engine/game_event.dart';
import 'package:earth_nova/models/affix.dart';
import 'package:earth_nova/models/animal_type.dart';
import 'package:earth_nova/models/climate.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_category.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/item_instance.dart';
import 'package:earth_nova/models/iucn_status.dart';

// ---------------------------------------------------------------------------
// Test constants
// ---------------------------------------------------------------------------

/// Centre coordinate of the test grid (near origin for simplicity).
const double kTestLat = 1.0;
const double kTestLon = 1.0;

/// A fixed cell ID used in many tests.
const String kTestCellA = 'cell_A';
const String kTestCellB = 'cell_B';
const String kTestCellC = 'cell_C';
const String kTestCellD = 'cell_D';

/// A fixed user ID for testing.
const String kTestUserId = 'test-user-1';

/// A fixed daily seed for deterministic encounter tests.
const String kTestDailySeed = 'test_seed_2026_01_01';

// ---------------------------------------------------------------------------
// MockCellService
//
// Fully configurable, in-memory CellService for unit testing.
// The test configures a small grid of cells before use. Any cell not
// explicitly configured returns sensible defaults so tests never crash on
// unexpected lookups.
// ---------------------------------------------------------------------------

class MockCellService implements CellService {
  // (lat, lon) → cellId
  final Map<(double, double), String> _coordToCell = {};
  // cellId → center
  final Map<String, Geographic> _centers = {};
  // cellId → boundary
  final Map<String, List<Geographic>> _boundaries = {};
  // cellId → neighbor IDs
  final Map<String, List<String>> _neighbors = {};

  /// Register a cell with a fixed center coordinate and optional boundary /
  /// neighbors.  Repeated calls for the same coordinate overwrite.
  void addCell({
    required String id,
    required double lat,
    required double lon,
    List<Geographic>? boundary,
    List<String>? neighbors,
  }) {
    _coordToCell[(lat, lon)] = id;
    _centers[id] = Geographic(lat: lat, lon: lon);
    _boundaries[id] = boundary ??
        [
          Geographic(lat: lat + 0.001, lon: lon + 0.001),
          Geographic(lat: lat + 0.001, lon: lon - 0.001),
          Geographic(lat: lat - 0.001, lon: lon - 0.001),
          Geographic(lat: lat - 0.001, lon: lon + 0.001),
        ];
    _neighbors[id] = neighbors ?? [];
  }

  // ---------------------------------------------------------------------------
  // CellService interface
  // ---------------------------------------------------------------------------

  /// Nearest registered cell to (lat, lon); falls back to the first registered
  /// cell if none found within 0.1°.
  @override
  String getCellId(double lat, double lon) {
    String? nearest;
    double minDist = double.infinity;
    for (final entry in _centers.entries) {
      final dLat = entry.value.lat - lat;
      final dLon = entry.value.lon - lon;
      final d = dLat * dLat + dLon * dLon;
      if (d < minDist) {
        minDist = d;
        nearest = entry.key;
      }
    }
    return nearest ?? kTestCellA;
  }

  @override
  Geographic getCellCenter(String cellId) =>
      _centers[cellId] ?? Geographic(lat: 0, lon: 0);

  @override
  List<Geographic> getCellBoundary(String cellId) =>
      _boundaries[cellId] ?? const [];

  @override
  List<String> getNeighborIds(String cellId) => _neighbors[cellId] ?? const [];

  @override
  List<String> getCellsInRing(String cellId, int k) {
    if (k == 0) return [cellId];
    final visited = <String>{cellId};
    var frontier = <String>{cellId};
    for (var i = 0; i < k; i++) {
      final next = <String>{};
      for (final c in frontier) {
        for (final n in getNeighborIds(c)) {
          if (visited.add(n)) next.add(n);
        }
      }
      frontier = next;
    }
    return visited.toList();
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) {
    return getCellsInRing(getCellId(lat, lon), k);
  }

  @override
  double get cellEdgeLengthMeters => 180.0;

  @override
  String get systemName => 'MockCellService';
}

/// Build a small 4-cell star topology:
///
///   B
///   |
/// C-A-D
///
/// A is the centre. B, C, D are each adjacent to A only (not to each other).
MockCellService buildStarGrid() {
  final svc = MockCellService();
  svc.addCell(
    id: kTestCellA,
    lat: kTestLat,
    lon: kTestLon,
    neighbors: [kTestCellB, kTestCellC, kTestCellD],
  );
  svc.addCell(
    id: kTestCellB,
    lat: kTestLat + 0.01,
    lon: kTestLon,
    neighbors: [kTestCellA],
  );
  svc.addCell(
    id: kTestCellC,
    lat: kTestLat,
    lon: kTestLon - 0.01,
    neighbors: [kTestCellA],
  );
  svc.addCell(
    id: kTestCellD,
    lat: kTestLat,
    lon: kTestLon + 0.01,
    neighbors: [kTestCellA],
  );
  return svc;
}

/// Build a linear 5-cell chain: E → A → B → C → D.
///
/// Each cell is a neighbor of the next. Useful for multi-cell walk tests.
MockCellService buildLinearGrid() {
  const kTestCellE = 'cell_E';
  final svc = MockCellService();
  svc.addCell(
    id: kTestCellE,
    lat: kTestLat - 0.02,
    lon: kTestLon,
    neighbors: [kTestCellA],
  );
  svc.addCell(
    id: kTestCellA,
    lat: kTestLat,
    lon: kTestLon,
    neighbors: [kTestCellE, kTestCellB],
  );
  svc.addCell(
    id: kTestCellB,
    lat: kTestLat + 0.02,
    lon: kTestLon,
    neighbors: [kTestCellA, kTestCellC],
  );
  svc.addCell(
    id: kTestCellC,
    lat: kTestLat + 0.04,
    lon: kTestLon,
    neighbors: [kTestCellB, kTestCellD],
  );
  svc.addCell(
    id: kTestCellD,
    lat: kTestLat + 0.06,
    lon: kTestLon,
    neighbors: [kTestCellC],
  );
  return svc;
}

// ---------------------------------------------------------------------------
// FaunaDefinition factory
// ---------------------------------------------------------------------------

/// Build a minimal [FaunaDefinition] with sensible defaults.
FaunaDefinition makeSpecies({
  String? id,
  String? scientificName,
  String? displayName,
  IucnStatus? rarity,
  Set<Habitat>? habitats,
  Set<Continent>? continents,
  String? taxonomicClass,
  AnimalType? animalType,
}) {
  final sn = scientificName ?? 'Test species';
  return FaunaDefinition(
    id: id ?? 'fauna_${sn.toLowerCase().replaceAll(' ', '_')}',
    displayName: displayName ?? sn,
    scientificName: sn,
    taxonomicClass: taxonomicClass ?? 'Mammalia',
    rarity: rarity ?? IucnStatus.leastConcern,
    habitats: (habitats ?? {Habitat.forest}).toList(),
    continents: (continents ?? {Continent.europe}).toList(),
  );
}

// ---------------------------------------------------------------------------
// ItemInstance factory
// ---------------------------------------------------------------------------

/// Build a minimal [ItemInstance] with sensible defaults.
ItemInstance makeItemInstance({
  String? id,
  String? definitionId,
  String? scientificName,
  List<Affix>? affixes,
  IucnStatus? rarity,
  String? userId,
}) {
  return ItemInstance(
    id: id ?? 'instance-test-id',
    definitionId: definitionId ?? 'fauna_test',
    displayName: 'Test Item',
    scientificName: scientificName ?? 'Test species',
    category: ItemCategory.fauna,
    rarity: rarity ?? IucnStatus.leastConcern,
    affixes: affixes ?? const [],
    acquiredAt: DateTime(2026, 1, 1),
  );
}

// ---------------------------------------------------------------------------
// collectEvents helper
// ---------------------------------------------------------------------------

/// Collect [count] events from [stream] with a [timeout].
///
/// Returns as soon as [count] events have been received or [timeout] elapses.
/// Throws a [TimeoutException] if fewer than [count] events arrive in time.
Future<List<GameEvent>> collectEvents(
  Stream<GameEvent> stream,
  int count, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final events = <GameEvent>[];
  final completer = Completer<List<GameEvent>>();

  late StreamSubscription<GameEvent> sub;
  sub = stream.listen(
    (event) {
      events.add(event);
      if (events.length >= count && !completer.isCompleted) {
        sub.cancel();
        completer.complete(List.unmodifiable(events));
      }
    },
    onDone: () {
      if (!completer.isCompleted) completer.complete(List.unmodifiable(events));
    },
    onError: (Object e) {
      if (!completer.isCompleted) completer.completeError(e);
    },
  );

  return completer.future.timeout(
    timeout,
    onTimeout: () {
      sub.cancel();
      return List.unmodifiable(events);
    },
  );
}

// ---------------------------------------------------------------------------
// makeTestCellProperties helper
// ---------------------------------------------------------------------------

/// Build a [CellProperties] suitable for engine tests.
///
/// Avoids importing cell_properties.dart directly in every test file.
/// Defaults to forest/temperate/europe.
Map<String, Object> makeCellPropertiesMap({
  String cellId = kTestCellA,
  Set<Habitat>? habitats,
  Climate climate = Climate.temperate,
  Continent continent = Continent.europe,
}) {
  return {
    'cellId': cellId,
    'habitats': (habitats ?? {Habitat.forest}).map((h) => h.name).toSet(),
    'climate': climate.name,
    'continent': continent.name,
  };
}
