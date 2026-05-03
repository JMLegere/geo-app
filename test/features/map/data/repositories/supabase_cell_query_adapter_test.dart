import 'package:earth_nova/features/map/data/repositories/supabase_cell_query_adapter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseCellQueryAdapter', () {
    test('delegates nearby geometry fetch to injected RPC query parameters', () async {
      final calls = <({double lat, double lng, double radiusMeters})>[];
      final adapter = SupabaseCellQueryAdapter(
        client: null,
        fetchCellsQuery: (lat, lng, radiusMeters) async {
          calls.add((lat: lat, lng: lng, radiusMeters: radiusMeters));
          return [
            {
              'cell_id': 'cell_rpc_1',
              'habitats': ['forest'],
              'polygon': [
                {'lat': 45.99, 'lng': -66.65},
                {'lat': 45.991, 'lng': -66.65},
                {'lat': 45.991, 'lng': -66.649},
                {'lat': 45.99, 'lng': -66.649},
              ],
              'polygons': [
                [
                  [
                    {'lat': 45.99, 'lng': -66.65},
                    {'lat': 45.991, 'lng': -66.65},
                    {'lat': 45.991, 'lng': -66.649},
                    {'lat': 45.99, 'lng': -66.649},
                  ],
                ],
              ],
              'district_id': 'district_brookside',
              'city_id': 'city_fredericton',
              'state_id': 'state_nb',
              'country_id': 'country_ca',
              'geometry_source_version': 'db-lattice-voronoi-beta-v1',
            },
          ];
        },
      );

      final cells = await adapter.fetchNearbyCells(
        lat: 45.99,
        lng: -66.65,
        radiusMeters: 2000,
        traceId: 'trace-map-fetch',
      );

      expect(calls, [
        (lat: 45.99, lng: -66.65, radiusMeters: 2000),
      ]);
      expect(cells, hasLength(1));
      expect(cells.single.id, 'cell_rpc_1');
      expect(cells.single.polygon, hasLength(4));
      expect(cells.single.cityId, 'city_fredericton');
    });

    test('filters empty polygons before returning domain cells', () async {
      final adapter = SupabaseCellQueryAdapter(
        client: null,
        fetchCellsQuery: (_, __, ___) async => [
          {
            'cell_id': 'empty_geometry',
            'habitats': ['forest'],
            'polygon': <Map<String, dynamic>>[],
          },
          {
            'cell_id': 'renderable_geometry',
            'habitats': ['forest'],
            'polygon': [
              {'lat': 1.0, 'lng': 1.0},
              {'lat': 1.0, 'lng': 2.0},
              {'lat': 2.0, 'lng': 2.0},
            ],
          },
        ],
      );

      final cells = await adapter.fetchNearbyCells(
        lat: 0,
        lng: 0,
        radiusMeters: 2000,
      );

      expect(cells.map((cell) => cell.id), ['renderable_geometry']);
    });
  });
}
