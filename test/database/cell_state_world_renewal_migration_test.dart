import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '101_cell_state_world_renewal.sql',
  );

  String sql() {
    if (!migration.existsSync()) {
      fail('Missing required migration: ${migration.path}');
    }
    return migration.readAsStringSync().toLowerCase();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String functionBody(String value, String functionName) {
    final match = RegExp(
      'create\\s+or\\s+replace\\s+function\\s+public\\.$functionName'
      r'\s*\([\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(value);
    expect(match, isNotNull, reason: 'Expected $functionName to be defined.');
    return match!.group(0)!.toLowerCase();
  }

  test('adds only the shared World renewal and private Cell State storage', () {
    final value = sql();
    final normalized = compact(value);

    for (final table in <String>[
      'v3_world_days',
      'v3_cell_opportunities',
      'v3_cell_current_opportunities',
      'v3_player_cell_knowledge',
      'v3_cell_visit_opportunities',
      'v3_cell_opportunity_refreshes',
    ]) {
      expect(
        normalized,
        contains('create table if not exists public.$table'),
      );
    }

    expect(normalized, contains('world_day date primary key'));
    expect(normalized, contains('world_seed bigint not null'));
    expect(normalized, contains('primary key (user_id, cell_id)'));
    expect(normalized, contains('cell_id text primary key'));
    expect(
      RegExp(
        r'cell_visit_id\s+uuid\s+primary key|primary key\s*\(\s*cell_visit_id\s*\)',
      ).hasMatch(normalized),
      isTrue,
    );
    expect(normalized, contains('cell_opportunity_id uuid not null'));
    expect(
      normalized,
      contains(
        'foreign key (cell_visit_id, user_id, cell_id) references public.v3_cell_visits(id, user_id, cell_id)',
      ),
    );
    expect(
      normalized,
      contains(
        'references public.v3_cell_opportunities(id)',
      ),
    );
    expect(value, contains('cell opportunities are immutable'));
    expect(value, contains('cell visit opportunity bindings are immutable'));
    expect(value, contains('cell opportunity refresh evidence is immutable'));
  });

  test(
      'catches every missed World Day up in order with one stable 5 percent roll',
      () {
    final normalized = compact(sql());
    final refresh =
        compact(functionBody(sql(), 'refresh_v3_cell_opportunities'));

    expect(
      normalized,
      contains("(now() at time zone 'utc')::date"),
      reason: 'World Day changes only at 00:00 UTC.',
    );
    expect(
      normalized,
      contains(
        'refresh_v3_cell_opportunities( p_cell_ids text[], p_world_day date default null )',
      ),
    );
    expect(
      refresh,
      contains(
        "v_world_day date := coalesce(p_world_day, (now() at time zone 'utc')::date)",
      ),
    );
    expect(refresh, contains('max(refresh.world_day)'));
    expect(refresh, contains('v_next_world_day'));
    expect(refresh, contains('generate_series('));
    expect(refresh, contains("interval '1 day'"));
    expect(refresh, contains('v_processed_world_day'));
    expect(
        refresh, contains('insert into public.v3_cell_opportunity_refreshes'));
    expect(refresh, contains('digest('));
    expect(refresh, contains("'sha256'"));
    expect(refresh, contains("'refresh_'"));
    expect(refresh, contains('% 10000'));
    expect(refresh,
        contains('if not v_has_current_opportunity or v_roll_bucket < 500'));
  });

  test('selects the Dart-compatible legacy candidate from its selector binding',
      () {
    final refresh =
        compact(functionBody(sql(), 'refresh_v3_cell_opportunities'));

    expect(RegExp(r"format\(\s*'seed_%s'").hasMatch(refresh), isTrue);
    expect(refresh, contains("to_char(v_processed_world_day, 'yyyy_mm_dd')"));
    expect(
      refresh,
      contains(
          "selector_candidate.selector_id = 'selector:legacy-cell-encounter'"),
    );
    expect(refresh, contains("selector_candidate.result_kind = 'value'"));
    expect(
        refresh, contains('order by candidate.ordinal, candidate.result_id'));
    expect(refresh, contains('v_content_bucket % candidate.candidate_count'));
  });

  test(
      'records immutable opportunity history and only replaces its current pointer',
      () {
    final normalized = compact(sql());
    final refresh =
        compact(functionBody(sql(), 'refresh_v3_cell_opportunities'));

    expect(refresh, contains('insert into public.v3_world_days'));
    expect(refresh, contains('on conflict (world_day) do nothing'));
    expect(refresh, contains('insert into public.v3_cell_opportunities'));
    expect(
        refresh, contains('insert into public.v3_cell_current_opportunities'));
    expect(
      normalized,
      isNot(contains('update public.v3_cell_opportunities')),
    );
  });

  test(
      'backfills private knowledge from Visits and refreshes only Explored rows to Informed',
      () {
    final normalized = compact(sql());
    final refresh =
        compact(functionBody(sql(), 'refresh_v3_cell_opportunities'));

    expect(
        normalized,
        contains(
            "knowledge_state text not null check (knowledge_state in ('explored', 'informed'))"));
    expect(
      normalized,
      contains(
          'insert into public.v3_player_cell_knowledge (user_id, cell_id, knowledge_state)'),
    );
    expect(normalized, contains('from public.v3_cell_visits as cell_visit'));
    expect(normalized, contains("'explored'"));
    expect(refresh, contains('update public.v3_player_cell_knowledge'));
    expect(refresh, contains("set knowledge_state = 'informed'"));
    expect(refresh, contains("knowledge_state = 'explored'"));
  });

  test(
      'preserves the Cell Visit command signature and does not demote Informed knowledge',
      () {
    final value = sql();
    final normalized = compact(value);
    final visit = compact(functionBody(value, 'record_v3_cell_visit'));

    expect(
      normalized,
      contains(
          'record_v3_cell_visit( p_cell_id text, p_client_event_id text )'),
    );
    expect(visit, contains('from public.v3_cell_current_opportunities'));
    expect(visit, contains('for update'));
    expect(visit, contains('insert into public.v3_cell_visit_opportunities'));
    expect(visit, contains('on conflict (cell_visit_id) do nothing'));
    expect(visit, contains('insert into public.v3_player_cell_knowledge'));
    expect(visit, contains('on conflict (user_id, cell_id) do nothing'));
    expect(
      visit,
      contains('perform public.refresh_v3_cell_opportunities(array[p_cell_id]);'),
    );
  });

  test('binds each new Encounter to its immutable Cell Visit Opportunity', () {
    final value = sql();
    final normalized = compact(value);
    final binding =
        compact(functionBody(value, 'v3_bind_encounter_cell_opportunity'));
    final limit = compact(functionBody(value, 'v3_limit_encounter_mutation'));

    expect(
      normalized,
      contains(
          'alter table public.v3_encounters add column if not exists cell_opportunity_id uuid'),
    );
    expect(
      RegExp(
        r'create\s+trigger\s+v3_encounters_bind_cell_opportunity\s+before\s+insert\s+on\s+public\.v3_encounters',
      ).hasMatch(normalized),
      isTrue,
    );
    expect(binding,
        contains('from public.v3_cell_visit_opportunities as binding'));
    expect(
        binding, contains('new.cell_opportunity_id := v_cell_opportunity_id'));
    expect(
        binding,
        contains(
            'new.encounter_definition_id is distinct from v_encounter_definition_id'));
    expect(
      binding,
      contains(
        'new.encounter_definition_version_id is distinct from v_encounter_definition_version_id',
      ),
    );
    expect(
      limit,
      contains(
          'new.cell_opportunity_id is distinct from old.cell_opportunity_id'),
    );
    expect(
      normalized,
      contains(
        'revoke all on function public.v3_bind_encounter_cell_opportunity() from public, anon, authenticated',
      ),
    );
  });

  test('exposes only authenticated category-level Cell State projections', () {
    final value = sql();
    final normalized = compact(value);
    final projection = functionBody(value, 'fetch_v3_player_cell_states');

    expect(
      normalized,
      contains(
          'fetch_v3_player_cell_states( p_cell_ids text[], p_world_day date default null )'),
    );
    expect(
      RegExp(
        r'returns\s+table\s*\(\s*cell_id\s+text\s*,\s*state\s+text\s*,\s*opportunity_category\s+text\s*\)',
      ).hasMatch(projection),
      isTrue,
      reason:
          'The RPC response contains exactly the three safe projection fields.',
    );
    expect(
        projection, contains('perform public.refresh_v3_cell_opportunities'));
    expect(
      projection,
      contains("coalesce(knowledge.knowledge_state, 'shrouded')"),
    );
    expect(projection, contains('then opportunity.category'));
    expect(projection, contains('end as opportunity_category'));
    expect(projection, contains('v_user_id uuid := auth.uid()'));
    expect(projection, contains('requires an authenticated user'));
    expect(
        normalized,
        contains(
            'revoke all on function public.fetch_v3_player_cell_states(text[], date) from public, anon'));
    expect(
        normalized,
        contains(
            'grant execute on function public.fetch_v3_player_cell_states(text[], date) to authenticated'));
    expect(projection, isNot(contains('content_json')));
    expect(projection, isNot(contains('encounter_definition_version_id')));
    expect(projection, isNot(contains('outcome')));
    expect(projection, isNot(contains('reward')));
  });

  test('accepts only today as a public World Day override', () {
    final value = sql();
    final normalized = compact(value);
    final projection = compact(
      functionBody(value, 'fetch_v3_player_cell_states'),
    );
    const currentDay =
        "p_world_day is distinct from (now() at time zone 'utc')::date";

    expect(projection, contains('p_world_day is not null'));
    expect(
      projection,
      contains(
        "v_world_day date := coalesce(p_world_day, (now() at time zone 'utc')::date)",
      ),
    );
    expect(projection, contains(currentDay));
    expect(
      projection,
      contains("raise exception 'world day must be today' using errcode = '22023'"),
    );
    expect(
      projection.indexOf(currentDay),
      lessThan(projection.indexOf('perform public.refresh_v3_cell_opportunities')),
    );
    expect(
      projection,
      isNot(contains("v_world_day > (now() at time zone 'utc')::date")),
    );
    expect(
      RegExp(
        r'create\s+or\s+replace\s+function\s+public\.fetch_v3_player_cell_states',
      ).allMatches(value).length,
      1,
    );
    expect(
      normalized,
      contains(
        'revoke all on function public.refresh_v3_cell_opportunities(text[], date) from public, anon, authenticated',
      ),
    );
  });

  test('does not mutate or destroy legacy Visit, Encounter, or result history',
      () {
    final normalized = compact(sql());

    for (final relation in <String>[
      'v3_cell_visits',
      'v3_encounters',
      'v3_encounter_outcome_results',
    ]) {
      expect(normalized, isNot(contains('update public.$relation')));
      expect(normalized, isNot(contains('delete from public.$relation')));
      expect(normalized, isNot(contains('truncate public.$relation')));
      expect(normalized, isNot(contains('drop table public.$relation')));
    }
    expect(normalized, isNot(contains('drop table')));
    expect(normalized, isNot(contains('truncate')));
  });
}
