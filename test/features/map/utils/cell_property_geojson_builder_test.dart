import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/event_resolver.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/features/map/utils/cell_property_geojson_builder.dart';
import 'package:earth_nova/features/map/utils/map_icon_renderer.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Geographic _center(String cellId) {
  final parts = cellId.split('_');
  return Geographic(
    lat: double.parse(parts[1]),
    lon: double.parse(parts[2]),
  );
}

CellProperties _makeProps(
  String cellId, {
  Set<Habitat> habitats = const {Habitat.forest},
  Climate climate = Climate.temperate,
  Continent continent = Continent.northAmerica,
}) {
  return CellProperties(
    cellId: cellId,
    habitats: habitats,
    climate: climate,
    continent: continent,
    locationId: null,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

Map<String, dynamic> _parse(String geoJson) =>
    jsonDecode(geoJson) as Map<String, dynamic>;

List<dynamic> _features(String geoJson) =>
    _parse(geoJson)['features'] as List<dynamic>;

/// Finds a daily seed where the given cell has an event.
String _findSeedWithEvent(String cellId) {
  for (var i = 0; i < 200; i++) {
    final seed = 'test_seed_$i';
    if (EventResolver.resolve(seed, cellId) != null) {
      return seed;
    }
  }
  throw StateError('Could not find seed with event for $cellId in 200 tries');
}

/// Finds a daily seed where the given cell has NO event.
String _findSeedWithoutEvent(String cellId) {
  for (var i = 0; i < 200; i++) {
    final seed = 'test_seed_$i';
    if (EventResolver.resolve(seed, cellId) == null) {
      return seed;
    }
  }
  throw StateError(
      'Could not find seed without event for $cellId in 200 tries');
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('CellPropertyGeoJsonBuilder', () {
    test('emptyFeatureCollection is valid GeoJSON', () {
      final parsed = _parse(CellPropertyGeoJsonBuilder.emptyFeatureCollection);
      expect(parsed['type'], 'FeatureCollection');
      expect(parsed['features'], isEmpty);
    });

    test('returns empty features when no cell properties provided', () {
      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {'cell_0_0': FogState.observed},
        cellProperties: {},
        currentCellId: 'cell_0_0',
        adjacentCellIds: {},
        visitedCellIds: {'cell_0_0'},
        dailySeed: 'seed',
        getCellCenter: _center,
      );

      expect(_features(json), isEmpty);
    });

    test('excludes undetected and unexplored cells', () {
      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {
          'cell_0_0': FogState.undetected,
          'cell_1_0': FogState.unexplored,
        },
        cellProperties: {
          'cell_0_0': _makeProps('cell_0_0'),
          'cell_1_0': _makeProps('cell_1_0'),
        },
        currentCellId: null,
        adjacentCellIds: {},
        visitedCellIds: {},
        dailySeed: 'seed',
        getCellCenter: _center,
      );

      expect(_features(json), isEmpty);
    });

    test('current cell without event shows no icons', () {
      const cellId = 'cell_45_10';
      final seedNoEvent = _findSeedWithoutEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.observed},
        cellProperties: {
          cellId: _makeProps(cellId,
              habitats: {Habitat.forest}, climate: Climate.temperate),
        },
        currentCellId: cellId,
        adjacentCellIds: {},
        visitedCellIds: {cellId},
        dailySeed: seedNoEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      // No event, so no icons.
      expect(features, isEmpty);
    });

    test('current cell shows event icon when event present', () {
      const cellId = 'cell_45_10';
      final seedWithEvent = _findSeedWithEvent(cellId);
      final event = EventResolver.resolve(seedWithEvent, cellId)!;

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.observed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: cellId,
        adjacentCellIds: {},
        visitedCellIds: {cellId},
        dailySeed: seedWithEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      // Only 1 icon: event (centered).
      expect(features.length, 1);

      final iconId = (features.first as Map)['properties']['icon'] as String;
      expect(iconId, MapIconRenderer.eventIconId(event.type.name));

      // Event icon should be centered (offset 0, 0).
      final offset = (features.first as Map)['properties']['offset'] as List;
      expect(offset[0], 0.0);
      expect(offset[1], 0.0);
    });

    test('visited non-adjacent cell without event shows no icons', () {
      const cellId = 'cell_45_10';
      final seedNoEvent = _findSeedWithoutEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.hidden},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: 'other_cell',
        adjacentCellIds: {},
        visitedCellIds: {cellId},
        dailySeed: seedNoEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      // Visited but no event: no icons.
      expect(features, isEmpty);
    });

    test('adjacent unvisited cell with event shows unknown icon', () {
      const cellId = 'cell_45_10';
      final seedWithEvent = _findSeedWithEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.concealed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: 'cell_0_0',
        adjacentCellIds: {cellId},
        visitedCellIds: {},
        dailySeed: seedWithEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      expect(features.length, 1);

      final iconId = (features.first as Map)['properties']['icon'] as String;
      expect(iconId, MapIconRenderer.eventUnknownId);
    });

    test('adjacent unvisited cell without event shows no icons', () {
      const cellId = 'cell_45_10';
      final seedNoEvent = _findSeedWithoutEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.concealed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: 'cell_0_0',
        adjacentCellIds: {cellId},
        visitedCellIds: {},
        dailySeed: seedNoEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      expect(features, isEmpty);
    });

    test('concealed non-adjacent non-visited cell shows no icons', () {
      const cellId = 'cell_45_10';

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.concealed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: 'cell_0_0',
        adjacentCellIds: {},
        visitedCellIds: {},
        dailySeed: 'seed',
        getCellCenter: _center,
      );

      final features = _features(json);
      expect(features, isEmpty);
    });

    test('icon features have correct GeoJSON Point coordinates', () {
      const cellId = 'cell_45_10';
      final seedWithEvent = _findSeedWithEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.observed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: cellId,
        adjacentCellIds: {},
        visitedCellIds: {cellId},
        dailySeed: seedWithEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      expect(features, isNotEmpty);

      final firstFeature = features.first as Map;
      final geometry = firstFeature['geometry'] as Map;
      expect(geometry['type'], 'Point');

      // Coordinates are [lon, lat] (GeoJSON convention).
      final coords = geometry['coordinates'] as List;
      expect(coords[0], 10.0); // lon
      expect(coords[1], 45.0); // lat
    });

    test('icon features have offset properties', () {
      const cellId = 'cell_45_10';
      final seedNoEvent = _findSeedWithoutEvent(cellId);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {cellId: FogState.observed},
        cellProperties: {cellId: _makeProps(cellId)},
        currentCellId: cellId,
        adjacentCellIds: {},
        visitedCellIds: {cellId},
        dailySeed: seedNoEvent,
        getCellCenter: _center,
      );

      final features = _features(json);
      for (final feature in features) {
        final props = (feature as Map)['properties'] as Map;
        expect(props.containsKey('offset'), isTrue);
        expect(props['offset'], isA<List>());
        expect((props['offset'] as List).length, 2);
        expect((props['offset'] as List)[0], isA<num>());
        expect((props['offset'] as List)[1], isA<num>());
      }
    });

    test('multiple cells with events produce multiple features', () {
      // Find a seed where both cells have events.
      String? goodSeed;
      for (var i = 0; i < 200; i++) {
        final seed = 'test_seed_$i';
        if (EventResolver.resolve(seed, 'cell_45_10') != null &&
            EventResolver.resolve(seed, 'cell_46_11') != null) {
          goodSeed = seed;
          break;
        }
      }
      expect(goodSeed, isNotNull);

      final json = CellPropertyGeoJsonBuilder.buildCellIcons(
        cellStates: {
          'cell_45_10': FogState.observed,
          'cell_46_11': FogState.hidden,
        },
        cellProperties: {
          'cell_45_10': _makeProps('cell_45_10'),
          'cell_46_11': _makeProps('cell_46_11'),
        },
        currentCellId: 'cell_45_10',
        adjacentCellIds: {},
        visitedCellIds: {'cell_45_10', 'cell_46_11'},
        dailySeed: goodSeed!,
        getCellCenter: _center,
      );

      final features = _features(json);
      // Both cells have events, so 2 features (1 per cell).
      expect(features.length, 2);
    });
  });

  group('MapIconRenderer', () {
    test('habitatIconId follows naming convention', () {
      expect(
        MapIconRenderer.habitatIconId('forest'),
        'habitat-forest',
      );
    });

    test('climateIconId follows naming convention', () {
      expect(
        MapIconRenderer.climateIconId('tropic'),
        'climate-tropic',
      );
    });

    test('eventIconId follows naming convention', () {
      expect(
        MapIconRenderer.eventIconId('migration'),
        'event-migration',
      );
    });

    test('eventUnknownId is event-unknown', () {
      expect(MapIconRenderer.eventUnknownId, 'event-unknown');
    });
  });
}
