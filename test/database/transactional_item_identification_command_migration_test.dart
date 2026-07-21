import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '088_transactional_item_identification_command.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String functionBlock(String sql, String name) => RegExp(
        r'CREATE OR REPLACE FUNCTION public\.' + name + r'\([\s\S]*?\$\$;',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  String tableBlock(String sql) => RegExp(
        r'CREATE TABLE IF NOT EXISTS public\.v3_item_identification_commits \([\s\S]*?\n\);',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  test('defines an immutable exact-bound receipt without a cached aggregate',
      () {
    final sql = readMigration();
    final table = tableBlock(sql).toLowerCase();

    expect(table, contains('item_id uuid primary key'));
    expect(table, contains('user_id uuid not null'));
    expect(table, contains('base_item_id text not null'));
    expect(table, contains('base_item_version_id uuid not null'));
    expect(table, contains("identification_kind in ('explicit', 'automatic')"));
    expect(table, contains('resolution_plan jsonb not null check'));
    expect(table, contains("jsonb_typeof(resolution_plan) = 'array'"));
    expect(table, contains('committed_at timestamptz not null'));
    expect(table, contains('created_at timestamptz not null default now()'));
    expect(
        table,
        contains(
            'foreign key (item_id, user_id, base_item_id, base_item_version_id)'));
    expect(
        table,
        contains(
            'references public.v3_items(id, user_id, base_item_id, base_item_version_id)'));
    expect(table, isNot(contains('aggregate jsonb')));
    expect(table, isNot(contains('property_resolutions')));

    final normalized = compact(sql).toLowerCase();
    expect(
      normalized,
      contains(
        'create trigger v3_item_identification_commits_immutable before update or delete on public.v3_item_identification_commits',
      ),
    );
    expect(
      normalized,
      contains(
          "raise exception 'item identification command receipts are immutable'"),
    );
  });

  test('exposes only authenticated prepare and commit RPCs', () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains(
        'revoke all on table public.v3_item_identification_commits from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke insert, update, delete on table public.v3_item_discoveries from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke insert, update, delete on table public.v3_item_property_values from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      isNot(contains('revoke update on table public.v3_items')),
      reason: '086 compatibility stays in place until the later client cutover',
    );
    expect(
      normalized,
      isNot(contains('drop policy if exists "v3_items_update_own"')),
      reason: '086 compatibility stays in place until the later client cutover',
    );
    for (final signature in <String>[
      'public.v3_deterministic_variable_property_candidate(uuid, text, text)',
      'public.v3_item_identification_aggregate(uuid)',
    ]) {
      expect(
        normalized,
        contains(
            'revoke all on function $signature from public, anon, authenticated'),
      );
    }
    expect(
      normalized,
      contains(
          'revoke all on function public.prepare_v3_item_identification(uuid) from public, anon'),
    );
    expect(
      normalized,
      contains(
          'grant execute on function public.prepare_v3_item_identification(uuid) to authenticated'),
    );
    expect(
      normalized,
      contains(
          'revoke all on function public.identify_v3_item(uuid, text, uuid, jsonb) from public, anon'),
    );
    expect(
      normalized,
      contains(
          'grant execute on function public.identify_v3_item(uuid, text, uuid, jsonb) to authenticated'),
    );
  });

  test(
      'preparation authenticates, locks only the owned exact Version, and returns normalized plan data',
      () {
    final prepare =
        functionBlock(readMigration(), 'prepare_v3_item_identification')
            .toLowerCase();

    expect(prepare, contains('v_user_id uuid := auth.uid()'));
    expect(prepare, contains('preparation requires an authenticated user'));
    expect(prepare, contains('item.id = p_item_id'));
    expect(prepare, contains('item.user_id = v_user_id'));
    expect(prepare, contains('for update'));
    expect(prepare, contains('version.id = v_item.base_item_version_id'));
    expect(prepare, contains('version.base_item_id = v_item.base_item_id'));
    expect(prepare,
        contains("version.publication_status in ('published', 'retired')"));
    expect(prepare, contains('for key share'));
    expect(prepare, contains('v3_base_item_version_variable_properties'));
    expect(prepare, contains('v3_variable_properties'));
    expect(prepare, contains('v3_selector_candidates'));
    expect(prepare, contains("'selected_candidate_id'"));
    expect(prepare, contains("'user_id', v_item.user_id"));
    expect(prepare, contains("'discovery'"));
    expect(prepare, isNot(contains('current_published_version_id')));
  });

  test(
      'recomputes the weighted unconditional candidate from the required sha-256 roll',
      () {
    final helper = functionBlock(
      readMigration(),
      'v3_deterministic_variable_property_candidate',
    ).toLowerCase();

    expect(helper, contains('extensions.digest('));
    expect(helper,
        contains("p_item_id::text || e'\\x1f' || p_variable_property_id"));
    expect(helper, contains("'sha256'"));
    expect(helper, contains("substring("));
    expect(helper, contains('from 1 for 8'));
    expect(helper, contains("'x00000000'"));
    expect(helper, contains('4294967296::numeric'));
    expect(helper, contains('sum(candidate.weight) over'));
    expect(helper, contains('order by candidate.ordinal'));
    expect(helper, contains('candidate.condition_id is null'));
    expect(
        helper,
        contains(
            'candidate.cumulative_weight > roll.unit_roll * candidate.total_weight'));
    expect(helper, contains('candidate.result_kind'));
    expect(helper, contains('candidate.result_id'));
    expect(helper, isNot(contains("result_kind = 'value'")),
        reason: 'explicit None must remain selectable');
  });

  test(
      'commit validates the complete dense exact plan before inserting any durable rows',
      () {
    final identify =
        functionBlock(readMigration(), 'identify_v3_item').toLowerCase();
    final firstPropertyInsert =
        identify.indexOf('insert into public.v3_item_property_values');

    expect(identify,
        contains('jsonb_typeof(p_property_resolutions) <> \'array\''));
    expect(identify, contains("input_row ?& array["));
    expect(identify, contains("input_row - array["));
    expect(identify, contains('selector_candidate_id'));
    expect(identify,
        contains('property resolutions must use dense ordered ordinals'));
    expect(
        identify,
        contains(
            'jsonb_array_length(p_property_resolutions) <> v_expected_count'));
    expect(identify, contains('exact version assignment at ordinal'));
    expect(identify, contains('candidate.condition_id is not null'));
    expect(identify,
        contains('unsupported conditioned variable property candidates'));
    expect(identify, contains('v3_deterministic_variable_property_candidate('));
    expect(
        identify, contains('does not match the deterministic server result'));
    expect(
        firstPropertyInsert,
        greaterThan(identify
            .indexOf('property resolutions are not a complete exact plan')));
    expect(
        firstPropertyInsert,
        greaterThan(identify
            .indexOf('does not match the deterministic server result')));
    expect(identify, isNot(contains('exception when')),
        reason: 'validation failures must abort the transaction');
  });

  test(
      'commit preserves first or repeat Discovery, writes only the seven-item projection, and replays canonically',
      () {
    final identify =
        functionBlock(readMigration(), 'identify_v3_item').toLowerCase();

    expect(identify, contains('insert into public.v3_item_discoveries'));
    expect(identify, contains("'explicit_identification'"));
    expect(
        identify, contains('on conflict (user_id, base_item_id) do nothing'));
    expect(identify, contains('select discovery.*'));
    expect(identify,
        contains('insert into public.v3_item_identification_commits'));
    expect(identify, contains("'explicit'"));
    expect(identify, contains('resolution_plan'));
    expect(identify,
        contains('return public.v3_item_identification_aggregate(v_item.id)'));
    expect(identify, contains('replay conflicts with its immutable receipt'));
    expect(identify, contains("v_receipt.identification_kind = 'explicit'"));

    final update = RegExp(
      r'UPDATE public\.v3_items[\s\S]*?WHERE id = v_item\.id',
      caseSensitive: false,
    ).firstMatch(identify)!.group(0)!;
    for (final field in <String>[
      'display_name',
      'scientific_name',
      'taxonomic_class',
      'habitats_json',
      'continents_json',
      'identification_state',
      'identified_at',
    ]) {
      expect(update, contains('$field ='));
    }
    expect(update, isNot(contains('rarity =')));
    expect(update, isNot(contains('base_item_id =')));
    expect(update, isNot(contains('base_item_version_id =')));
    expect(identify, isNot(contains('current_published_version_id')));
  });

  test(
      'canonical aggregate is exact-bound and has exactly the public aggregate keys',
      () {
    final aggregate =
        functionBlock(readMigration(), 'v3_item_identification_aggregate')
            .toLowerCase();

    expect(aggregate, contains('version.id = v_item.base_item_version_id'));
    expect(aggregate, contains('version.base_item_id = v_item.base_item_id'));
    expect(
        aggregate,
        contains(
            'assignment.base_item_version_id = v_item.base_item_version_id'));
    expect(aggregate, contains("'item', jsonb_build_object("));
    expect(aggregate, contains("'discovery', case"));
    expect(aggregate, contains("'property_values', v_property_values"));
    expect(aggregate, contains("'identification', jsonb_build_object("));
    expect(aggregate, contains('v_receipt.identification_kind'));
    expect(aggregate, contains('v_receipt.committed_at'));
    expect(aggregate, isNot(contains('current_published_version_id')));
  });

  test('does not add xp, progression, destructive cleanup, or rarity mechanics',
      () {
    final sql = readMigration().toLowerCase();

    expect(sql, isNot(contains('v3_discipline_progress')));
    expect(sql, isNot(contains(' xp ')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('set rarity =')));
    expect(sql, isNot(contains('update public.v3_base_item_versions')));
    expect(sql, isNot(contains('insert into public.v3_items')));
  });
}
