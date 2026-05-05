import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffered coverage migration expands organic geometry source footprint', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/055_stage_invalid_buffered_rows_with_reasons.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE FUNCTION stage_cell_geometry_from_organic_centroids'));
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
    expect(sql, contains('p_coverage_buffer_meters DOUBLE PRECISION DEFAULT 250.0'));
    expect(sql, isNot(contains('metadata = EXCLUDED.metadata')));
    expect(sql, contains('geometry_null_after_clip'));
    expect(sql, contains('geometry_empty_after_clip'));
    expect(sql, contains('geometry_invalid_after_clip'));
    expect(sql, contains('geometry_nonpositive_area_after_clip'));
    expect(sql, isNot(contains('WHERE geom IS NOT NULL')));
  });
}
