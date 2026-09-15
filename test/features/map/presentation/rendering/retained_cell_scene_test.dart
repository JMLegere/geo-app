import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/player_marker_state.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/player_marker.dart';
import 'package:earth_nova/ui/product_surfaces/map/platform/retained_map_renderer.dart';
import 'package:earth_nova/ui/product_surfaces/map/rendering/retained_cell_scene.dart';

void main() {
  test(
    'state-only changes omit retained geometry, even for reconstructed cells',
    () {
      final scene = RetainedCellScene();
      final first = scene.update([(cell: cell(), state: present)]);
      expect(first['geometry'], isNotNull);
      final unchanged = scene.update([(cell: cell(), state: present)]);
      expect(unchanged['geometry'], isNull);
      final informed = scene.update([
        (
          cell: cell(),
          state: const CellState(
            knowledgeState: CellKnowledgeState.informed,
            category: 'fauna',
            relationship: CellRelationship.explored,
            contents: CellContents.empty,
          ),
        ),
      ]);
      expect(informed['geometry'], isNull);
      expect(informed['states'], [containsPair('knowledge', 'informed')]);
      expect(informed['states'], [containsPair('relationship', 'explored')]);
      expect(informed['states'], [containsPair('cue', 'fauna')]);
      final changed = scene.update([(cell: cell(lng: 4), state: present)]);
      expect(changed['geometry'], isNotNull);
      expect(scene.update([])['geometry'], isNotNull);
    },
  );
  test('replacement native map receives full geometry again', () {
    final scene = RetainedCellScene();
    final entries = [(cell: cell(), state: present)];
    final initial = scene.update(entries)['geometry'];
    expect(scene.update(entries)['geometry'], isNull);
    scene.reset();
    expect(scene.update(entries)['geometry'], initial);
    expect(scene.update(entries)['geometry'], isNull);
  });
  test(
    'scene preserves complete polygon holes and disconnected components',
    () {
      final scene = RetainedCellScene();
      final geometry = scene.update([
        (cell: cell(), state: present),
      ])['geometry'];
      expect(geometry, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'a',
            'properties': <String, Object?>{},
            'geometry': {
              'type': 'MultiPolygon',
              'coordinates': [
                [
                  [
                    [0.0, 0.0],
                    [3.0, 0.0],
                    [3.0, 3.0],
                    [0.0, 3.0],
                    [0.0, 0.0],
                  ],
                  [
                    [1.0, 1.0],
                    [2.0, 1.0],
                    [2.0, 2.0],
                    [1.0, 1.0],
                  ],
                ],
                [
                  [
                    [5.0, 0.0],
                    [6.0, 0.0],
                    [6.0, 1.0],
                    [5.0, 0.0],
                  ],
                ],
              ],
            },
          },
        ],
      });
    },
  );
  test(
    'native fallback is unsupported and safely ignores lifecycle calls',
    () async {
      final renderer = RetainedMapRenderer();
      expect(await renderer.attach(), isFalse);
      expect(renderer.isAttached, isFalse);
      await renderer.updateScene([(cell: cell(), state: present)]);
      renderer.updatePlayer(
        const PlayerMarkerState(lat: 0, lng: 0, isRing: false, gapDistance: 0),
        trust: PlayerMarkerTrust.trusted,
      );
      renderer.updateCameraTarget((lat: 0, lng: 0));
      renderer.dispose();
      renderer.dispose();
      expect(await renderer.attach(), isFalse);
    },
  );
}

const present = CellState(
  relationship: CellRelationship.present,
  contents: CellContents.empty,
);
Cell cell({double lng = 0}) => Cell(
  id: 'a',
  habitats: const [],
  districtId: 'd',
  cityId: 'c',
  stateId: 's',
  countryId: 'x',
  polygons: [
    [
      [
        (lat: 0, lng: lng),
        (lat: 0, lng: 3),
        (lat: 3, lng: 3),
        (lat: 3, lng: 0),
      ],
      [(lat: 1, lng: 1), (lat: 1, lng: 2), (lat: 2, lng: 2)],
    ],
    [
      [(lat: 0, lng: 5), (lat: 0, lng: 6), (lat: 1, lng: 6)],
    ],
  ],
);
