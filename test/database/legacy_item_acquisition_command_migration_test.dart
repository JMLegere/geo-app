import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '085_legacy_item_acquisition_command.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test(
      'defines an authenticated legacy discovery command with no caller-owned identity or binding',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.acquire_v3_legacy_discovery_item(\n'
        '  p_definition_id TEXT,\n'
        '  p_display_name TEXT,\n'
        '  p_category TEXT,\n'
        '  p_acquired_in_cell_id TEXT,',
      ),
    );
    expect(sql, contains('RETURNS JSONB'));
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public'));
    expect(sql, contains('v_user_id UUID := auth.uid()'));
    expect(sql, isNot(contains('p_user_id')));
    expect(sql, isNot(contains('p_base_item_id')));
    expect(sql, isNot(contains('p_base_item_version_id')));
    expect(sql, contains('p_map_cell_entry_id TEXT DEFAULT NULL'));
    expect(sql, contains('trace-only'));
  });

  test(
      'validates bounded trimmed evidence, lifecycle state, and JSON array shape',
      () {
    final sql = readMigration();

    expect(sql, contains('btrim(p_definition_id)'));
    expect(sql, contains('btrim(p_display_name)'));
    expect(sql, contains('btrim(p_category)'));
    expect(sql, contains('btrim(p_acquired_in_cell_id)'));
    expect(sql, contains('char_length(p_definition_id) > 512'));
    expect(
        sql,
        contains(
            "v_category NOT IN ('fauna', 'flora', 'mineral', 'fossil', 'artifact', 'food', 'orb')"));
    expect(
      sql,
      contains(
          "p_identification_state <> 'unidentified' OR p_identified_at IS NOT NULL"),
    );
    expect(
      sql,
      contains(
          'Legacy discovery acquisition must begin unidentified without identified_at'),
    );
    expect(sql, contains("jsonb_typeof(p_habitats_json) <> 'array'"));
    expect(sql, contains("jsonb_typeof(p_continents_json) <> 'array'"));
    expect(
        sql, contains("jsonb_typeof(p_identified_habitats_json) <> 'array'"));
    expect(
        sql, contains("jsonb_typeof(p_identified_continents_json) <> 'array'"));
    expect(sql, contains('jsonb_array_elements(p_habitats_json)'));
    expect(
        sql,
        contains(
            'Item habitat and continent evidence must be bounded trimmed strings'));
  });

  test(
      'accepts only the eight server catalog species and locks the exact current Version',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        "'^species\\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\\.[0-9a-f]{8}\$'",
      ),
    );
    expect(sql,
        contains('Legacy discovery definition is not in the server catalog'));
    expect(sql, contains('079 legacy-item identities are historical bindings'));
    expect(sql, isNot(contains("'legacy-item:' || md5(")));
    expect(sql, isNot(contains('INSERT INTO public.v3_base_items')));
    expect(sql, contains('FROM public.v3_base_items AS base_item'));
    expect(sql, contains('FOR UPDATE'));
    expect(
        sql,
        contains(
            'base_item_version.id = v_base_item.current_published_version_id'));
    expect(sql, contains('base_item_version.base_item_id = v_base_item.id'));
    expect(sql, contains("base_item_version.publication_status = 'published'"));
    expect(sql, contains('FOR KEY SHARE'));
    expect(sql,
        contains('current published Version is unavailable or mismatched'));
    expect(sql, contains('base_item_id,'));
    expect(sql, contains('base_item_version_id'));
    expect(sql, contains('v_base_item.id,'));
    expect(sql, contains('v_base_item_version.id'));
    expect(
        sql,
        contains(
            'Rarity is legacy evidence only and is never used for identity, selection,'));
  });

  test(
      'returns the canonical compatible retry but rejects an incompatible reuse without rewriting Items',
      () {
    final sql = readMigration();

    expect(sql, contains('pg_advisory_xact_lock(hashtextextended('));
    expect(sql, contains('item.user_id = v_user_id'));
    expect(sql, contains('item.definition_id = v_definition_id'));
    expect(sql, contains('item.acquired_in_cell_id = v_acquired_in_cell_id'));
    expect(sql, contains("item.status = 'active'"));
    expect(sql, contains('FOR UPDATE'));
    expect(
        sql,
        contains(
            'Legacy discovery Item retry has incompatible evidence for its active Item'));
    expect(
      sql,
      contains(
          'A delayed acquisition retry must return this canonical Item rather than'),
    );
    expect(sql, contains('v_item.identified_display_name IS DISTINCT FROM'));
    expect(sql,
        contains('v_item.identified_habitats_json::jsonb IS DISTINCT FROM'));
    expect(sql, isNot(contains('v_item.display_name IS DISTINCT FROM')));
    expect(sql, isNot(contains('v_item.scientific_name IS DISTINCT FROM')));
    expect(sql, isNot(contains('v_item.taxonomic_class IS DISTINCT FROM')));
    expect(
        sql, isNot(contains('v_item.habitats_json::jsonb IS DISTINCT FROM')));
    expect(
        sql, isNot(contains('v_item.continents_json::jsonb IS DISTINCT FROM')));
    expect(
        sql, isNot(contains('v_item.identification_state IS DISTINCT FROM')));
    expect(sql, isNot(contains('v_item.identified_at IS DISTINCT FROM')));
    expect(sql, contains('RETURN to_jsonb(v_item)'));
    expect(sql, isNot(contains('UPDATE public.v3_items')));
    expect(sql, isNot(contains('DELETE FROM public.v3_items')));
    expect(sql, isNot(contains('TRUNCATE TABLE public.v3_items')));
    expect(sql, isNot(contains('DROP TABLE public.v3_items')));
  });

  test(
      'server-stamps the complete Item and exposes the command only to authenticated callers',
      () {
    final sql = readMigration();

    expect(sql, contains('v_now TIMESTAMPTZ := now()'));
    expect(sql, contains("'active',"));
    expect(sql, contains('RETURNING * INTO v_item'));
    expect(sql, contains('RETURN to_jsonb(v_item)'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.acquire_v3_legacy_discovery_item(\n'
        '  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TIMESTAMPTZ,\n'
        '  TEXT, TEXT, TEXT, JSONB, JSONB, TEXT\n'
        ') FROM PUBLIC, anon',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.acquire_v3_legacy_discovery_item(\n'
        '  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, JSONB, JSONB, TEXT, TIMESTAMPTZ,\n'
        '  TEXT, TEXT, TEXT, JSONB, JSONB, TEXT\n'
        ') TO authenticated',
      ),
    );
  });
}
