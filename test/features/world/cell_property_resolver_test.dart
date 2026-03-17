import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/world/services/cell_property_resolver.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';

// ── Test doubles ─────────────────────────────────────────────────────────────

class _StubHabitatLookup implements HabitatLookup {
  final Set<Habitat> Function(double lat, double lon) _fn;
  _StubHabitatLookup(this._fn);

  @override
  Set<Habitat> classifyLocation(double lat, double lon) => _fn(lat, lon);
}

class _StubContinentLookup implements ContinentLookup {
  final Continent Function(double lat, double lon) _fn;
  _StubContinentLookup(this._fn);

  @override
  Continent resolve(double lat, double lon) => _fn(lat, lon);
}

void main() {
  // ---------------------------------------------------------------------------
  // Basic resolution
  // ---------------------------------------------------------------------------

  group('CellPropertyResolver resolve', () {
    test('returns properties with correct cellId', () {
      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.forest}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      final props = resolver.resolve(
        cellId: 'v_42_17',
        lat: 45.0,
        lon: -75.0,
      );

      expect(props.cellId, equals('v_42_17'));
    });

    test('resolves habitats from HabitatLookup', () {
      final resolver = CellPropertyResolver(
        habitatLookup:
            _StubHabitatLookup((_, __) => {Habitat.forest, Habitat.freshwater}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      final props = resolver.resolve(cellId: 'v_1_1', lat: 45.0, lon: -75.0);

      expect(props.habitats, equals({Habitat.forest, Habitat.freshwater}));
    });

    test('falls back to Plains when HabitatLookup returns empty set', () {
      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      final props = resolver.resolve(cellId: 'v_1_1', lat: 45.0, lon: -75.0);

      expect(props.habitats, equals({Habitat.plains}));
    });

    test('resolves climate from latitude', () {
      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.plains}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      // Tropic: abs(lat) <= 23.5
      expect(
        resolver.resolve(cellId: 'c1', lat: 10.0, lon: 0.0).climate,
        equals(Climate.tropic),
      );

      // Temperate: 23.5 < abs(lat) <= 55
      expect(
        resolver.resolve(cellId: 'c2', lat: 45.0, lon: 0.0).climate,
        equals(Climate.temperate),
      );

      // Boreal: 55 < abs(lat) <= 66.5
      expect(
        resolver.resolve(cellId: 'c3', lat: 60.0, lon: 0.0).climate,
        equals(Climate.boreal),
      );

      // Frigid: abs(lat) > 66.5
      expect(
        resolver.resolve(cellId: 'c4', lat: 75.0, lon: 0.0).climate,
        equals(Climate.frigid),
      );

      // Southern hemisphere
      expect(
        resolver.resolve(cellId: 'c5', lat: -5.0, lon: 0.0).climate,
        equals(Climate.tropic),
      );
    });

    test('resolves continent from ContinentLookup', () {
      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.plains}),
        continentLookup: _StubContinentLookup((_, __) => Continent.africa),
      );

      final props = resolver.resolve(cellId: 'v_1_1', lat: -1.0, lon: 36.0);

      expect(props.continent, equals(Continent.africa));
    });

    test('locationId is always null (backfilled async)', () {
      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.plains}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      final props = resolver.resolve(cellId: 'v_1_1', lat: 45.0, lon: -75.0);

      expect(props.locationId, isNull);
    });

    test('createdAt is set to approximately now', () {
      final before = DateTime.now();

      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.plains}),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      final props = resolver.resolve(cellId: 'v_1_1', lat: 45.0, lon: -75.0);
      final after = DateTime.now();

      expect(props.createdAt.isAfter(before.subtract(Duration(seconds: 1))),
          isTrue);
      expect(props.createdAt.isBefore(after.add(Duration(seconds: 1))), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Coordinate forwarding
  // ---------------------------------------------------------------------------

  group('CellPropertyResolver coordinate forwarding', () {
    test('passes correct lat/lon to HabitatLookup', () {
      double? receivedLat;
      double? receivedLon;

      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((lat, lon) {
          receivedLat = lat;
          receivedLon = lon;
          return {Habitat.plains};
        }),
        continentLookup:
            _StubContinentLookup((_, __) => Continent.northAmerica),
      );

      resolver.resolve(cellId: 'v_1_1', lat: 42.123, lon: -73.456);

      expect(receivedLat, equals(42.123));
      expect(receivedLon, equals(-73.456));
    });

    test('passes correct lat/lon to ContinentLookup', () {
      double? receivedLat;
      double? receivedLon;

      final resolver = CellPropertyResolver(
        habitatLookup: _StubHabitatLookup((_, __) => {Habitat.plains}),
        continentLookup: _StubContinentLookup((lat, lon) {
          receivedLat = lat;
          receivedLon = lon;
          return Continent.northAmerica;
        }),
      );

      resolver.resolve(cellId: 'v_1_1', lat: 42.123, lon: -73.456);

      expect(receivedLat, equals(42.123));
      expect(receivedLon, equals(-73.456));
    });
  });

  // ---------------------------------------------------------------------------
  // All habitats
  // ---------------------------------------------------------------------------

  group('CellPropertyResolver all habitats', () {
    test('supports all 7 habitat types', () {
      for (final habitat in Habitat.values) {
        final resolver = CellPropertyResolver(
          habitatLookup: _StubHabitatLookup((_, __) => {habitat}),
          continentLookup:
              _StubContinentLookup((_, __) => Continent.northAmerica),
        );

        final props = resolver.resolve(cellId: 'v_1_1', lat: 45.0, lon: -75.0);
        expect(props.habitats, contains(habitat));
      }
    });
  });
}
