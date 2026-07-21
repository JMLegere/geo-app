import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '081_transactional_encounter_resolution_rpcs.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test('is additive and adds traceable generated Item result binding', () {
    final sql = readMigration();

    expect(sql, contains('ADD COLUMN IF NOT EXISTS generated_item_id UUID'));
    expect(sql, contains('REFERENCES public.v3_items(id)'));
    expect(sql, contains('UNIQUE (generated_item_id)'));
    expect(sql,
        contains('v3_encounter_outcome_results_kind_specific_binding_check'));
    expect(sql, contains('generated_item_id IS NOT NULL'));
    expect(sql, contains('generated_item_id IS NULL'));
    expect(sql, contains('v3_validate_encounter_outcome_result'));
    expect(sql, contains('item.base_item_id'));
    expect(sql, contains('item.base_item_version_id'));
    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(sql, isNot(contains('TRUNCATE TABLE')));
    expect(sql, isNot(contains('DELETE FROM')));
    expect(sql.toLowerCase(), isNot(contains('rarity')));
  });

  test('limits encounters to immutable identity and one terminal transition',
      () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            'CREATE OR REPLACE FUNCTION public.v3_limit_encounter_mutation()'));
    expect(sql, contains("OLD.resolution_status <> 'pending'"));
    expect(
        sql, contains("NEW.resolution_status NOT IN ('resolved', 'failed')"));
    expect(
        sql,
        contains(
            'NEW.selected_option_id IS DISTINCT FROM OLD.selected_option_id'));
    expect(sql, contains('NEW.resolved_at IS DISTINCT FROM OLD.resolved_at'));
    expect(sql, contains('NEW.failure_code IS DISTINCT FROM OLD.failure_code'));
    expect(sql, contains('Encounter terminal states are immutable'));
    expect(sql, contains('Encounter occurrences cannot be deleted'));
  });

  test(
      'creates the explicit cell visit resolution command with exact signature',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.resolve_v3_cell_visit_encounter(\n'
        '  p_cell_visit_id UUID,\n'
        '  p_selector_id TEXT,\n'
        '  p_selector_candidate_id UUID,\n'
        '  p_expected_encounter_definition_version_id UUID DEFAULT NULL\n'
        ')\nRETURNS JSONB',
      ),
    );
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public'));
    expect(sql, contains('auth.uid()'));
    expect(sql, contains('cell_visit.user_id = v_user_id'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains("selector.status = 'active'"));
    expect(sql, contains("selector.result_type = 'encounter_definition'"));
    expect(sql, contains('candidate.id = p_selector_candidate_id'));
    expect(sql, contains('candidate.selector_id = p_selector_id'));
    expect(sql, contains("v_candidate.result_kind = 'none'"));
    expect(sql, contains("v_candidate.result_kind <> 'value'"));
    expect(sql,
        contains('p_expected_encounter_definition_version_id IS NOT NULL'));
    expect(sql, contains('v_definition.current_published_version_id'));
    expect(
      sql,
      contains(
        'IS DISTINCT FROM p_expected_encounter_definition_version_id',
      ),
    );
    expect(sql, contains('Cell Visit resolution retry input differs'));
    expect(
        sql,
        contains(
            'None Cell Visit resolution must not provide an expected Encounter Definition Version'));
    expect(sql, contains("      'none',\n      NULL"));
    expect(sql, contains("    'encounter',\n    v_definition.id"));
    expect(sql, contains('jsonb_build_object'));
  });

  test('applies outcomes through one all-or-none command with exact signature',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.resolve_v3_encounter_outcomes(\n'
        '  p_encounter_id UUID,\n'
        '  p_selected_option_id UUID DEFAULT NULL\n'
        ')\nRETURNS JSONB',
      ),
    );
    expect(sql, contains('encounter.id = p_encounter_id'));
    expect(sql, contains('cell_visit.user_id = v_user_id'));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, isNot(contains('INTO v_encounter, v_cell_id')));
    expect(sql, contains('SELECT cell_visit.cell_id\n  INTO v_cell_id'));
    expect(sql, contains("v_encounter.resolution_status = 'resolved'"));
    expect(sql, contains("v_encounter.resolution_status = 'failed'"));
    expect(sql, contains('Resolved Encounter retry selected Option differs'));
    expect(sql,
        contains('Automatic Encounter requires exactly one implicit Option'));
    expect(sql, contains('Manual Encounter requires an explicit Option'));
    expect(
        sql,
        contains(
            'Manual Encounter Option belongs to a different Encounter Definition Version'));
    expect(sql, contains('Unsupported Encounter Option Condition'));
    expect(sql, contains('ORDER BY outcome.ordinal'));
    expect(sql, contains('FOR UPDATE OF base_item'));
    // Migration 081's rejection is historical compatibility evidence.
    // Migration 093 supersedes this branch with atomic Reveal Venue support.
    expect(sql, contains('Unsupported Reveal Venue Outcome'));
    expect(
        sql,
        contains(
            'BEGIN\n    -- The nested exception block rolls back every Item and Outcome Result'));
    expect(sql, contains('EXCEPTION WHEN OTHERS THEN'));
    expect(sql, contains("SET resolution_status = 'failed'"));
    expect(sql, contains('failure_code = v_failure_code'));
    expect(sql, contains('v_result_count <> v_outcome_count'));
    expect(sql, contains('EXCEPT'));
    expect(sql, contains('Encounter Outcome Result set is incomplete'));
    final outcomeCommand = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.resolve_v3_encounter_outcomes[\s\S]*?\$\$;',
    ).firstMatch(sql)!.group(0)!;
    expect(
      RegExp(
        r'SELECT outcome\.ordinal[\s\S]*?EXCEPT[\s\S]*?SELECT result\.outcome_ordinal',
      ).hasMatch(outcomeCommand),
      isTrue,
    );
    expect(
      outcomeCommand,
      contains('WHERE result.encounter_id = v_encounter.id'),
    );
  });

  test(
      'generates items from locked current Base Item Version and exact result linkage',
      () {
    final sql = readMigration();

    expect(sql, contains('base_item.current_published_version_id'));
    expect(
        sql,
        contains(
            'base_item_version.id = v_base_item.current_published_version_id'));
    expect(sql, contains("base_item_version.publication_status = 'published'"));
    expect(sql, contains('INSERT INTO public.v3_items'));
    expect(sql, contains('base_item_id,'));
    expect(sql, contains('base_item_version_id,'));
    expect(sql, contains('acquired_in_cell_id,'));
    expect(sql, contains("'active'"));
    expect(sql, contains('INSERT INTO public.v3_encounter_outcome_results'));
    expect(sql, contains('resolved_base_item_version_id,'));
    expect(sql, contains('generated_item_id'));
    expect(sql, contains('v_generated_item.id'));
  });

  test(
      'returns exact immutable Version triples without current-pointer lookups',
      () {
    final sql = readMigration();
    final aggregate = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.v3_encounter_runtime_aggregate[\s\S]*?\$\$;',
    ).firstMatch(sql)!.group(0)!;

    expect(
        aggregate,
        contains(
            "'encounter_definition_revision', encounter_version.revision"));
    expect(
      aggregate,
      contains(
          'JOIN public.v3_encounter_definition_versions AS encounter_version'),
    );
    expect(
      aggregate,
      contains(
          "'resolved_base_item_id', resolved_base_item_version.base_item_id"),
    );
    expect(
      aggregate,
      contains(
          "'resolved_base_item_revision', resolved_base_item_version.revision"),
    );
    expect(
      aggregate,
      contains(
          'LEFT JOIN public.v3_base_item_versions AS resolved_base_item_version'),
    );
    expect(aggregate,
        contains("'base_item_revision', item_base_item_version.revision"));
    expect(
      aggregate,
      contains('JOIN public.v3_base_item_versions AS item_base_item_version'),
    );
    expect(aggregate, isNot(contains('current_published_version_id')));
  });

  test('exposes only command RPCs to authenticated and keeps helpers private',
      () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            'REVOKE ALL ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) FROM PUBLIC'));
    expect(
        sql,
        contains(
            'GRANT EXECUTE ON FUNCTION public.resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) TO authenticated'));
    expect(
        sql,
        contains(
            'REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) FROM PUBLIC'));
    expect(
        sql,
        contains(
            'GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID) TO authenticated'));
    expect(
        sql,
        contains(
            'REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID) FROM PUBLIC'));
    expect(
        sql,
        contains(
            'REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_result() FROM PUBLIC'));
    expect(sql, isNot(contains('FOR INSERT TO authenticated')));
    expect(sql, isNot(contains('FOR UPDATE TO authenticated')));
    expect(sql, isNot(contains('FOR DELETE TO authenticated')));
  });
}
