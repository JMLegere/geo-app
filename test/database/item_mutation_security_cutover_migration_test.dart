import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '086_item_mutation_security_cutover.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String identificationGate(String sql) => RegExp(
        r'CREATE OR REPLACE FUNCTION public\.'
        r'v3_limit_item_identification_mutation\(\)[\s\S]*?\$\$;',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  test('aborts before the cutover when any Item lacks an exact binding', () {
    final sql = readMigration().toLowerCase();

    expect(sql, contains('assert_v3_items_are_bound_for_mutation_cutover'));
    expect(sql, contains('from public.v3_items'));
    expect(
      sql,
      contains('where base_item_id is null or base_item_version_id is null'),
    );
    expect(sql, contains('v_unbound_count <> 0'));
    expect(
      sql,
      contains(
          'item mutation security cutover requires zero unbound item rows'),
    );
  });

  test('allows exactly the temporary Identification projection to change', () {
    final gate = identificationGate(readMigration());

    expect(gate, contains('to_jsonb(NEW)'));
    expect(gate, contains('to_jsonb(OLD)'));
    expect(gate, contains('IS DISTINCT FROM'));
    expect(
        gate,
        contains(
            'Item updates may change only the temporary Identification projection'));

    const allowedFields = <String>[
      'display_name',
      'scientific_name',
      'taxonomic_class',
      'habitats_json',
      'continents_json',
      'identification_state',
      'identified_at',
    ];
    for (final field in allowedFields) {
      expect(gate, contains("'$field'"));
    }

    const protectedFields = <String>[
      'id',
      'user_id',
      'definition_id',
      'category',
      'rarity',
      'icon_url',
      'icon_url_frame2',
      'art_url',
      'acquired_at',
      'acquired_in_cell_id',
      'status',
      'base_item_id',
      'base_item_version_id',
      'identified_display_name',
      'identified_scientific_name',
      'identified_taxonomic_class',
      'identified_habitats_json',
      'identified_continents_json',
      'created_at',
    ];
    for (final field in protectedFields) {
      expect(gate, isNot(contains("'$field'")),
          reason: '$field must remain immutable');
    }

    final normalized = compact(readMigration()).toLowerCase();
    expect(
      normalized,
      contains(
        'create trigger v3_items_identification_projection_only '
        'before update on public.v3_items for each row execute function '
        'public.v3_limit_item_identification_mutation()',
      ),
    );
  });

  test(
      'retains narrow Identification compatibility only until its transactional command',
      () {
    final sql = readMigration().toLowerCase();

    expect(sql, contains('temporary compatibility'));
    expect(sql,
        contains('until the transactional identification command replaces it'));
    expect(sql, contains('existing own-row select'));
    expect(sql, contains('temporary own-row update policy remain unchanged'));
    expect(sql, isNot(contains('drop policy if exists "v3_items_select_own"')));
    expect(sql, isNot(contains('drop policy if exists "v3_items_update_own"')));
    expect(sql, isNot(contains('revoke update on table public.v3_items')));
  });

  test('closes direct Item insertion and deletion without reopening a policy',
      () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains(
        'revoke insert, delete on table public.v3_items from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      contains(
          'drop policy if exists "v3_items_insert_own" on public.v3_items'),
    );
    expect(
      normalized,
      contains(
          'drop policy if exists "v3_items_delete_own" on public.v3_items'),
    );
    expect(
        normalized, isNot(contains('grant insert on table public.v3_items')));
    expect(
        normalized, isNot(contains('grant delete on table public.v3_items')));
    expect(normalized, isNot(contains('create policy "v3_items_insert_own"')));
    expect(normalized, isNot(contains('create policy "v3_items_delete_own"')));
    expect(
      normalized,
      contains(
        'revoke all on function public.v3_limit_item_identification_mutation() '
        'from public, anon, authenticated',
      ),
    );
  });

  test('keeps only the authenticated Item creation commands executable', () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains(
        'revoke all on function public.resolve_v3_cell_visit_encounter(uuid, text, uuid, uuid) from public, anon',
      ),
    );
    expect(
      normalized,
      contains(
        'grant execute on function public.resolve_v3_cell_visit_encounter(uuid, text, uuid, uuid) to authenticated',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke all on function public.resolve_v3_encounter_outcomes(uuid, uuid) from public, anon',
      ),
    );
    expect(
      normalized,
      contains(
        'grant execute on function public.resolve_v3_encounter_outcomes(uuid, uuid) to authenticated',
      ),
    );
    const legacyAcquireSignature = 'public.acquire_v3_legacy_discovery_item( '
        'text, text, text, text, text, text, text, jsonb, jsonb, text, '
        'timestamptz, text, text, text, jsonb, jsonb, text )';
    expect(
      normalized,
      contains(
          'revoke all on function $legacyAcquireSignature from public, anon'),
    );
    expect(
      normalized,
      contains(
          'grant execute on function $legacyAcquireSignature to authenticated'),
    );
  });

  test('performs no Item row rewrite or destructive cleanup', () {
    final sql = readMigration().toLowerCase();

    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('drop table')));
    expect(
      RegExp(r'\binsert\s+into\s+public\.v3_items\b').hasMatch(sql),
      isFalse,
    );
    expect(
      RegExp(r'\bupdate\s+public\.v3_items\b').hasMatch(sql),
      isFalse,
    );
    expect(sql,
        contains('item rows are never rewritten, deleted, or rebound here'));
  });
}
