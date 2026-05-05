import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffered coverage migration expands organic geometry source footprint', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/053_use_containment_for_buffered_boundary_assignment.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE OR REPLACE FUNCTION stage_cell_geometry_from_organic_centroids'));
    expect(sql, contains('ST_Buffer('));
    expect(sql, contains('v_coverage_buffer_meters'));
    expect(sql, contains('true-voronoi-clipped-to-buffered-lattice-coverage'));
    expect(sql, contains('coverage_buffer_meters'));
    expect(sql, contains('artifact_uri'));
    expect(sql, contains('raw_geometry'));
    expect(sql, contains('parsed_bbox'));
    expect(sql, contains('parsed_area_m2'));
    expect(sql, contains('validation_errors'));
    expect(sql, isNot(contains('validation_message')));
    expect(sql, contains('ST_Covers('));
    expect(sql, contains('validation_summary'));
    expect(sql, isNot(contains('metadata = EXCLUDED.metadata')));
  });
}
