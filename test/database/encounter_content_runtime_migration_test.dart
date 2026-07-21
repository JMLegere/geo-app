import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '078_encounter_content_and_runtime.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test(
      'adds authored property assignments through their canonical generalized selector',
      () {
    final sql = readMigration();

    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS public.v3_variable_properties'));
    expect(
        sql, contains('CREATE TABLE IF NOT EXISTS public.v3_property_values'));
    expect(
      sql,
      contains(
        'CREATE TABLE IF NOT EXISTS public.v3_base_item_version_variable_properties',
      ),
    );
    expect(sql, contains('base_item_version_id UUID NOT NULL'));
    expect(sql, contains('variable_property_id TEXT NOT NULL'));
    expect(
      sql,
      contains(
        "category TEXT CHECK (category IN ( 'fauna', 'flora', 'mineral', "
        "'fossil', 'artifact', 'food', 'orb' ))",
      ),
    );
    expect(
        sql,
        contains(
            'selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)'));
    expect(sql, contains('v3_validate_variable_property_selector'));
    expect(sql, contains('v3_prevent_variable_property_mutation'));
    expect(sql, contains('v3_prevent_property_value_mutation'));
    expect(sql, contains('CREATE TRIGGER v3_variable_properties_immutable'));
    expect(sql, contains('CREATE TRIGGER v3_property_values_immutable'));
    expect(sql, contains('UNIQUE (base_item_version_id, ordinal)'));

    final assignmentTable = RegExp(
      r'CREATE TABLE IF NOT EXISTS public\.v3_base_item_version_variable_properties \([\s\S]*?\n\);',
    ).firstMatch(sql)!.group(0)!;
    expect(assignmentTable, isNot(contains('selector_id')));
  });

  test('encounter definitions publish immutable owned versions', () {
    final sql = readMigration();

    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS public.v3_encounter_definitions'));
    expect(
      sql,
      contains(
          'CREATE TABLE IF NOT EXISTS public.v3_encounter_definition_versions'),
    );
    expect(sql, contains('current_published_version_id UUID'));
    expect(sql, contains('UNIQUE (encounter_definition_id, revision)'));
    expect(sql, contains('UNIQUE (encounter_definition_id, id)'));
    expect(
        sql,
        contains(
            'eligibility_condition_id TEXT REFERENCES public.v3_conditions(id)'));
    expect(sql, contains('publish_v3_encounter_definition_version'));
    expect(sql,
        contains('prevent_published_v3_encounter_definition_version_mutation'));
    expect(sql, isNot(contains('entry_selector_id')));
  });

  test('options and outcomes have domain-significant ordering', () {
    final sql = readMigration();

    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS public.v3_encounter_options'));
    expect(sql,
        contains('CREATE TABLE IF NOT EXISTS public.v3_encounter_outcomes'));
    expect(sql, contains('UNIQUE (encounter_definition_version_id, ordinal)'));
    expect(sql, contains('UNIQUE (encounter_option_id, ordinal)'));
    expect(sql, contains('is_automatic BOOLEAN NOT NULL DEFAULT FALSE'));
    expect(sql, contains('is_implicit BOOLEAN NOT NULL DEFAULT FALSE'));
    expect(sql, contains('v3_validate_automatic_encounter_options'));
  });

  test('outcomes are typed JSON data with no executable escape hatch', () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            "kind TEXT NOT NULL CHECK (kind IN ('generate_item', 'reveal_venue'))"));
    expect(sql, contains('payload JSONB NOT NULL'));
    expect(sql, contains('v3_validate_encounter_outcome_payload'));
    expect(sql, contains("ARRAY['script', 'code', 'function', 'expression']"));
    final executableKeyGuard = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.v3_encounter_payload_contains_executable_key[\s\S]*?\$\$;',
    ).firstMatch(sql)!.group(0)!;
    expect(
      executableKeyGuard,
      contains('ELSE'),
      reason: 'Scalar JSON payload nodes must not raise CASE_NOT_FOUND.',
    );
    expect(sql, contains("p_payload ? 'base_item_id'"));
    expect(sql, contains("p_payload ? 'venue_id'"));
    expect(sql, isNot(contains('quantity')));
    expect(sql, isNot(contains('rarity')));
  });

  test(
      'uses PostgreSQL-compatible immutable exact-key checks for Outcome payloads',
      () {
    final sql = readMigration();
    final payloadValidator = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.v3_validate_encounter_outcome_payload[\s\S]*?\$\$;',
    ).firstMatch(sql)!.group(0)!;

    const unsupportedPostgresFunction = 'jsonb_object' '_length';
    expect(sql, isNot(contains(unsupportedPostgresFunction)));
    expect(
      payloadValidator,
      contains("(p_payload - 'base_item_id') = '{}'::jsonb"),
    );
    expect(
      payloadValidator,
      contains("(p_payload - 'venue_id') = '{}'::jsonb"),
    );
  });

  test(
      'cell visit resolution makes None versus Encounter explicit and binds versions',
      () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            'CREATE TABLE IF NOT EXISTS public.v3_cell_visit_resolutions'));
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.v3_encounters'));
    expect(
        sql,
        contains(
            'CREATE TABLE IF NOT EXISTS public.v3_encounter_outcome_results'));
    expect(sql, contains('cell_visit_id UUID NOT NULL UNIQUE'));
    expect(
        sql,
        contains(
            'selector_id TEXT NOT NULL REFERENCES public.v3_selectors(id)'));
    expect(
        sql,
        contains(
            'selector_candidate_id UUID NOT NULL REFERENCES public.v3_selector_candidates(id)'));
    expect(
        sql,
        contains(
            "resolution_kind TEXT NOT NULL CHECK (resolution_kind IN ('none', 'encounter'))"));
    expect(sql, contains('encounter_definition_id TEXT'));
    final encounterTable = RegExp(
      r'CREATE TABLE IF NOT EXISTS public\.v3_encounters \([\s\S]*?\n\);',
    ).firstMatch(sql)!.group(0)!;
    expect(
      RegExp(
        r"resolution_status = 'failed'[\s\S]*?resolved_at IS NULL[\s\S]*?failure_code IS NOT NULL",
      ).hasMatch(encounterTable),
      isTrue,
    );
    expect(
      encounterTable,
      isNot(
        contains(
          "resolution_status = 'failed'\n      AND selected_option_id IS NOT NULL",
        ),
      ),
    );
    expect(sql, contains('encounter_definition_version_id UUID NOT NULL'));
    expect(sql, contains('failure_code TEXT'));
    expect(sql, contains('failure_details JSONB'));
    expect(sql, contains("resolution_status = 'failed'"));
    expect(sql, contains('UNIQUE (cell_visit_id, id)'));
    expect(
        sql, contains('FOREIGN KEY (cell_visit_id, cell_visit_resolution_id)'));
    expect(sql, contains('UNIQUE (encounter_id, outcome_ordinal)'));
  });

  test(
      'runtime records expose only their owning player and authored content is read-only',
      () {
    final sql = readMigration();

    expect(
        sql,
        contains(
            'ALTER TABLE public.v3_cell_visit_resolutions ENABLE ROW LEVEL SECURITY'));
    expect(sql,
        contains('ALTER TABLE public.v3_encounters ENABLE ROW LEVEL SECURITY'));
    expect(
        sql,
        contains(
            'ALTER TABLE public.v3_encounter_outcome_results ENABLE ROW LEVEL SECURITY'));
    expect(
        sql, contains('CREATE POLICY "v3_cell_visit_resolutions_select_own"'));
    expect(sql, contains('CREATE POLICY "v3_encounters_select_own"'));
    expect(sql, contains('v3_prevent_cell_visit_resolution_mutation'));
    expect(sql, contains('CREATE TRIGGER v3_cell_visit_resolutions_immutable'));
    expect(sql, contains('v3_limit_encounter_mutation'));
    expect(
        sql, contains('CREATE TRIGGER v3_encounters_limit_identity_mutation'));
    expect(sql, contains('v3_prevent_encounter_outcome_result_mutation'));
    expect(
        sql, contains('CREATE TRIGGER v3_encounter_outcome_results_immutable'));
    expect(sql,
        contains('CREATE POLICY "v3_encounter_outcome_results_select_own"'));
    expect(sql, contains('cell_visit.user_id = auth.uid()'));
    expect(sql, contains('FOR SELECT TO authenticated'));
    final runtimePolicies = RegExp(
      r'CREATE POLICY "v3_(?:cell_visit_resolutions|encounters|encounter_outcome_results)_[^"]+"[\s\S]*?;',
    ).allMatches(sql).map((match) => match.group(0)!).toList();
    expect(runtimePolicies, hasLength(3));
    for (final policy in runtimePolicies) {
      expect(policy, contains('FOR SELECT TO authenticated'));
      expect(
        RegExp(r'FOR\s+(?:INSERT|UPDATE|DELETE)\s+TO\s+authenticated')
            .hasMatch(policy),
        isFalse,
      );
    }
  });

  test(
      'migration is additive and does not introduce encounter-specific selectors',
      () {
    final sql = readMigration();

    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(sql, isNot(contains('TRUNCATE TABLE')));
    expect(sql, isNot(contains('DELETE FROM')));
    expect(sql, isNot(contains('v3_encounter_selectors')));
    expect(sql, isNot(contains('v3_item_selectors')));
    expect(sql, isNot(contains('entry_selector_id')));
  });
}
