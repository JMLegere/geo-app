import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '084_item_knowledge_progression_foundation.sql',
  );

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('is additive and leaves legacy Item records untouched', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(
        sql, contains('create table if not exists public.v3_item_discoveries'));
    expect(sql,
        contains('create table if not exists public.v3_item_property_values'));
    expect(sql,
        contains('create table if not exists public.v3_discipline_progress'));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('update public.v3_items')));
    expect(sql, isNot(contains('alter table public.v3_items drop')));
  });

  test(
      'Discovery has one Player and stable Base Item identity with exact first Item Version ownership',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    expect(normalized, contains('primary key (user_id, base_item_id)'));
    expect(normalized, contains('first_identified_item_id uuid not null'));
    expect(normalized, contains('first_base_item_version_id uuid not null'));
    expect(
      normalized,
      contains(
        "provenance in ( 'legacy_backfill', 'explicit_identification', "
        "'automatic_identification' )",
      ),
    );
    expect(
      normalized,
      contains(
        'unique (id, user_id, base_item_id, base_item_version_id)',
      ),
    );
    expect(
      normalized,
      contains(
        'foreign key ( first_identified_item_id, user_id, base_item_id, first_base_item_version_id ) references public.v3_items( id, user_id, base_item_id, base_item_version_id )',
      ),
    );
    expect(
      normalized,
      contains(
        'foreign key (base_item_id, first_base_item_version_id) references public.v3_base_item_versions(base_item_id, id)',
      ),
    );
  });

  test(
      'Property Values bind to their owning Item exact Version and exact Selector candidate result',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    expect(
      normalized,
      contains('unique (item_id, variable_property_key)'),
    );
    expect(
      normalized,
      contains(
        'foreign key (item_id, user_id, base_item_id, base_item_version_id) references public.v3_items(id, user_id, base_item_id, base_item_version_id)',
      ),
    );
    expect(
      normalized,
      contains('unique (selector_id, id)'),
    );
    expect(
      normalized,
      contains(
        'foreign key (selector_id, selector_candidate_id) references public.v3_selector_candidates(selector_id, id)',
      ),
    );
    expect(
        sqlContainsAll(normalized, [
          'variable_property_key text not null',
          'resolved_at timestamptz not null',
          'v3_validate_item_property_value_resolution',
          'v_candidate_kind is distinct from new.resolution_kind',
          'v_candidate_result_id is distinct from new.resolved_value_id',
        ]),
        isTrue);
  });

  test(
      'Property Value resolution explicitly preserves a None candidate rather than omitting it',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    expect(
        normalized,
        contains(
            "resolution_kind text not null check (resolution_kind in ('value', 'none'))"));
    expect(
      normalized,
      contains("(resolution_kind = 'none' and resolved_value_id is null)"),
    );
    expect(
      normalized,
      contains(
        "( resolution_kind = 'value' and btrim(coalesce(resolved_value_id, '')) <> ''",
      ),
    );
  });

  test(
      'backfills exactly one deterministic legacy Discovery without property or progression invention',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    expect(
        normalized, contains('partition by item.user_id, item.base_item_id'));
    expect(
      normalized,
      contains(
          'item.identified_at asc nulls last, item.acquired_at asc, item.id asc'),
    );
    expect(normalized, contains("'legacy_backfill'"));
    expect(normalized, contains('where item.discovery_rank = 1'));
    expect(
        normalized, contains('on conflict (user_id, base_item_id) do nothing'));
    expect(
        normalized, contains('coalesce(item.identified_at, item.acquired_at)'));
    expect(
      RegExp(r'insert\s+into\s+public\.v3_item_property_values',
              caseSensitive: false)
          .hasMatch(normalized),
      isFalse,
    );
    expect(
      RegExp(r'insert\s+into\s+public\.v3_discipline_progress',
              caseSensitive: false)
          .hasMatch(normalized),
      isFalse,
    );
    expect(
      RegExp(r'update\s+public\.v3_discipline_progress', caseSensitive: false)
          .hasMatch(normalized),
      isFalse,
    );
  });

  test(
      'Discipline Progress is storage-only for exactly five disciplines with no invented curve',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    expect(
      normalized,
      contains(
          "discipline in ( 'zoology', 'botany', 'geology', 'paleontology', 'archaeology' )"),
    );
    expect(normalized, contains('xp bigint not null check (xp >= 0)'));
    expect(normalized, contains('level integer not null check (level > 0)'));
    expect(normalized, isNot(contains('xp bigint not null default')));
    expect(normalized, isNot(contains('level integer not null default')));
    expect(normalized, isNot(contains('discipline_progress_events')));
  });

  test('committed Discoveries and Property Values cannot be updated or deleted',
      () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('v3_item_discoveries_immutable'));
    expect(
        sql, contains('before update or delete on public.v3_item_discoveries'));
    expect(sql,
        contains("raise exception 'committed item discoveries are immutable'"));
    expect(sql, contains('v3_item_property_values_immutable'));
    expect(sql,
        contains('before update or delete on public.v3_item_property_values'));
    expect(
        sql,
        contains(
            "raise exception 'committed item property values are immutable'"));
  });

  test(
      'RLS allows authenticated Players to read only their own rows and grants no direct writes',
      () {
    final normalized = compact(migration.readAsStringSync()).toLowerCase();

    for (final table in <String>[
      'v3_item_discoveries',
      'v3_item_property_values',
      'v3_discipline_progress',
    ]) {
      expect(normalized,
          contains('alter table public.$table enable row level security'));
      expect(
          normalized,
          contains(
              'on public.$table for select to authenticated using (auth.uid() = user_id)'));
    }
    expect(normalized, isNot(contains('for insert to authenticated')));
    expect(normalized, isNot(contains('for update to authenticated')));
    expect(normalized, isNot(contains('for delete to authenticated')));
    expect(
      normalized,
      contains(
        'revoke all on function public.'
        'v3_validate_item_property_value_resolution() '
        'from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke all on function public.v3_prevent_item_discovery_mutation() '
        'from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke all on function public.'
        'v3_prevent_item_property_value_mutation() '
        'from public, anon, authenticated',
      ),
    );
  });

  test(
      'repeat-safe assertions reject unbound Items and incomplete legacy Discovery backfill',
      () {
    final sql = migration.readAsStringSync().toLowerCase();

    expect(sql, contains('assert_v3_items_have_exact_base_item_bindings'));
    expect(sql,
        contains('where base_item_id is null or base_item_version_id is null'));
    expect(sql, contains('assert_v3_item_discoveries_are_backfilled'));
    expect(sql, contains('left join public.v3_item_discoveries as discovery'));
    expect(sql, contains('where discovery.user_id is null'));
  });
}

bool sqlContainsAll(String sql, List<String> fragments) =>
    fragments.every(sql.contains);
