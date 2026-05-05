import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffered coverage migration expands organic geometry source footprint', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/050_buffer_organic_geometry_coverage.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE OR REPLACE FUNCTION stage_cell_geometry_from_organic_centroids'));
    expect(sql, contains('ST_Buffer('));
    expect(sql, contains('v_coverage_buffer_meters'));
    expect(sql, contains('true-voronoi-clipped-to-buffered-lattice-coverage'));
    expect(sql, contains('coverage_buffer_meters'));
  });
}
