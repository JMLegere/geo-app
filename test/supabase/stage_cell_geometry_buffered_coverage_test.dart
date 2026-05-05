import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('buffered coverage migration expands organic geometry source footprint', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/061_handle_singleton_buffered_clusters.sql',
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
    expect(sql, contains('ST_ClusterDBSCAN('));
    expect(sql, contains('cluster_id'));
    expect(sql, contains('clusters.centroid_count = 1'));
    expect(sql, contains('ST_Dump(clusters.coverage_geom)'));
  });

  test('preview diagnostics migration exposes buffered drop reason counts', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/056_preview_buffered_stage_drop_reasons.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(
      sql,
      contains('CREATE FUNCTION diagnose_stage_cell_geometry_from_organic_centroids'),
    );
    expect(sql, contains('candidate_row_count'));
    expect(sql, contains('valid_candidate_count'));
    expect(sql, contains('null_geom_count'));
    expect(sql, contains('empty_geom_count'));
    expect(sql, contains('invalid_geom_count'));
    expect(sql, contains('nonpositive_area_count'));
  });

  test('focused boundary preview migration exposes local drop reason counts', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/059_fix_lattice_decode_in_boundary_preview.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(
      sql,
      contains('CREATE OR REPLACE FUNCTION diagnose_stage_cell_geometry_boundary_window'),
    );
    expect(sql, contains('p_focus_lat DOUBLE PRECISION'));
    expect(sql, contains('p_focus_lng DOUBLE PRECISION'));
    expect(sql, contains('p_focus_radius_meters DOUBLE PRECISION DEFAULT 500.0'));
    expect(sql, contains('p_site_radius_meters DOUBLE PRECISION DEFAULT 1200.0'));
    expect(sql, contains('p_boundary_band_meters DOUBLE PRECISION DEFAULT 300.0'));
    expect(sql, contains('focus_cell_count'));
    expect(sql, contains('FROM cell_properties cp'));
    expect(
      sql,
      contains("split_part(cp.cell_id, '_', 2)::INTEGER / 500.0 AS original_center_lat"),
    );
    expect(
      sql,
      contains("split_part(cp.cell_id, '_', 3)::INTEGER / 500.0 AS original_center_lng"),
    );
    expect(sql, contains('null_geom_count'));
    expect(sql, contains('empty_geom_count'));
    expect(sql, contains('invalid_geom_count'));
    expect(sql, contains('nonpositive_area_count'));
  });
}