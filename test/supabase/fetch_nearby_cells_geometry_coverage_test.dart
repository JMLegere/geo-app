import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetch_nearby_cells uses indexed geometry coverage before JSON projection', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/073_optimize_fetch_nearby_cells.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE FUNCTION fetch_nearby_cells'));
    expect(sql, contains('nearby_geometry AS'));
    expect(sql, contains('FROM cell_geometry_current cell_geom'));
    expect(sql, contains('cell_geom.geom && ST_Expand'));
    expect(sql, contains('cell_geom.geom::geography'));
    expect(sql, contains('nearby_cells AS'));

    final geometryFilterIndex = sql.indexOf('nearby_geometry AS');
    final jsonProjectionIndex =
        sql.indexOf('cell_geometry_latlng_polygons_jsonb');
    expect(geometryFilterIndex, isNonNegative);
    expect(jsonProjectionIndex, isNonNegative);
    expect(geometryFilterIndex, lessThan(jsonProjectionIndex));

    expect(
      sql,
      isNot(
        contains(
          'ST_SetSRID(ST_MakePoint(model.centroid_lon, model.centroid_lat), 4326)::geography',
        ),
      ),
    );
  });
}
