import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fetch_nearby_cells migration uses geometry coverage instead of centroid-only distance', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/049_fetch_nearby_cells_geometry_coverage.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE FUNCTION fetch_nearby_cells'));
    expect(sql, contains('JOIN cell_geometry_current cell_geom'));
    expect(sql, contains('cell_geom.geom::geography'));
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
