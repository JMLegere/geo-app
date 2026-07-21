import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '098_secure_item_identity_boundary.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test(
      'replaces legacy acquisition with only discovery identity and provenance',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE FUNCTION public.acquire_v3_legacy_discovery_item(\n'
        '  p_definition_id TEXT,\n'
        '  p_acquired_in_cell_id TEXT,\n'
        '  p_map_cell_entry_id TEXT DEFAULT NULL\n'
        ')',
      ),
    );
    for (final forbiddenInput in const <String>[
      'p_display_name',
      'p_category',
      'p_scientific_name',
      'p_rarity',
      'p_taxonomic_class',
      'p_habitats_json',
      'p_continents_json',
      'p_identification_state',
      'p_identified_at',
    ]) {
      expect(sql, isNot(contains(forbiddenInput)));
    }
    expect(sql, contains('v_base_item.current_published_version_id'));
    expect(sql, contains('v_base_item_version.authored_content'));
    expect(sql, contains('pg_advisory_xact_lock'));
    expect(sql, contains('WHERE item.user_id = v_user_id'));
  });

  test('removes direct Item reads and exposes owner-bound safe Pack projection',
      () {
    final sql = readMigration();

    expect(sql, contains('REVOKE SELECT ON TABLE public.v3_items'));
    expect(sql,
        contains('CREATE OR REPLACE FUNCTION public.fetch_v3_pack_items()'));
    expect(sql, contains('v3_safe_item_projection'));
    expect(sql,
        contains('GRANT EXECUTE ON FUNCTION public.fetch_v3_pack_items()'));
    expect(sql, contains('WHERE item.user_id = v_user_id'));
  });

  test(
      'masks unidentified Item identity yet preserves canonical identified data',
      () {
    final sql = readMigration();

    expect(
        sql, contains("WHEN p_item.identification_state = 'identified' THEN"));
    expect(
        sql,
        contains(
            "'display_name', 'Unidentified ' || lower(p_item.category) || ' specimen'"));
    expect(sql, contains("'definition_id', p_item.definition_id"));
    expect(
        sql, contains("'base_item_version_id', p_item.base_item_version_id"));
  });

  test(
      'masks generated Item and Generate Item outcome evidence before Identification',
      () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            'CREATE OR REPLACE FUNCTION public.v3_encounter_runtime_aggregate('));
    expect(
        sql,
        contains(
            "WHEN item.identification_state = 'identified' THEN result.resolved_base_item_version_id"));
    expect(
        sql,
        contains(
            "WHEN item.identification_state = 'identified' THEN resolved_base_item_version.base_item_id"));
    expect(sql, contains("WHEN item.identification_state = 'identified' THEN"));
    expect(sql, contains('public.v3_safe_item_projection(item)'));
  });
}
