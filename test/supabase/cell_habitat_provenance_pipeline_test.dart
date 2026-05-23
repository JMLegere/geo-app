import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('habitat provenance migration adds auditable classification pipeline',
      () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/075_cell_habitat_provenance_pipeline.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('ALTER TABLE cell_properties'));
    expect(sql, contains('habitat_source_version TEXT'));
    expect(sql, contains('habitat_confidence TEXT'));
    expect(sql, contains('habitat_provenance JSONB'));
    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS cell_habitat_source_versions'));
    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS cell_habitat_source_features'));
    expect(sql, contains('normalized_habitat IN ('));
    expect(sql, contains("'urban'"));
    expect(
        sql,
        contains(
            'CREATE TABLE IF NOT EXISTS cell_habitat_classification_runs'));
    expect(
        sql,
        contains(
            'CREATE TABLE IF NOT EXISTS cell_habitat_classification_results'));
    expect(
        sql,
        contains(
            'CREATE OR REPLACE FUNCTION classify_cell_habitats_from_source_version('));
    expect(sql, contains('ST_Intersection(cell.geom, feature.geom)'));
    expect(sql, contains('jsonb_object_agg('));
    expect(sql, contains('UPDATE cell_properties cp'));
    expect(sql, contains("habitat_source = v_source"));
    expect(sql, contains("habitat_confidence = result.habitat_confidence"));
    expect(sql, contains('DROP FUNCTION IF EXISTS fetch_nearby_cells('));
    expect(sql, contains('habitat_source_version TEXT,'));
    expect(sql, contains('habitat_confidence TEXT,'));
    expect(sql, contains('cp.habitat_source_version'));
    expect(sql, contains('cp.habitat_confidence'));
  });
}
