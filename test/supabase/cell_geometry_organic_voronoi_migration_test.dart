import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('organic Voronoi staging migration replaces square source truth', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/044_stage_cell_geometry_from_organic_centroids.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('stage_cell_geometry_from_organic_centroids'));
    expect(sql, contains('ST_VoronoiPolygons'));
    expect(sql, contains('db-deterministic-jittered-centroid-voronoi'));
    expect(sql, contains('centroid_dataset_version'));
    expect(sql, contains('geometry_contract'));
    expect(sql, contains('true-voronoi-clipped-to-lattice-coverage'));
    expect(sql, contains('cell_geometry_publish_events'));
    expect(sql, isNot(contains('uniform-lattice-bounded-voronoi')));
  });

  test('geometry validation timeout supports beta-scale organic Voronoi', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/045_cell_geometry_validation_timeout.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('validate_cell_geometry_source_version'));
    expect(sql, contains("statement_timeout = '600s'"));
  });

  test('geometry visual quality migration surfaces provenance contract', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/046_cell_geometry_visual_quality_and_provenance.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('cell_geometry_visual_quality_summary'));
    expect(sql, contains('cell-geometry-visual-quality-v1'));
    expect(sql, contains('visual_quality_passed'));
    expect(sql, contains('geometry_generation_mode'));
    expect(sql, contains('centroid_dataset_version'));
    expect(sql, contains('geometry_contract'));
    expect(sql, contains('geometry_visual_quality'));
    expect(sql, contains('fetch_nearby_cells'));
  });
}
