import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/077_conditions_and_selectors.sql',
  );

  test(
      'conditions and selectors migration creates only additive v3 rule tables',
      () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.v3_conditions'));
    expect(sql, contains('CREATE TABLE IF NOT EXISTS public.v3_selectors'));
    expect(
      sql,
      contains('CREATE TABLE IF NOT EXISTS public.v3_selector_candidates'),
    );
    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(sql, isNot(contains('TRUNCATE TABLE')));
    expect(sql, isNot(contains('DELETE FROM')));
    expect(sql, isNot(contains('v3_encounter_selectors')));
    expect(sql, isNot(contains('v3_item_selectors')));
  });

  test(
      'conditions use a schema-versioned recursive typed AST without code fields',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('condition_schema_version INTEGER NOT NULL'));
    expect(sql, contains('condition_ast JSONB NOT NULL'));
    expect(sql, contains("IN ('all', 'any', 'not', 'leaf')"));
    expect(sql, contains('v3_validate_condition_ast'));
    expect(sql, contains("jsonb_typeof(p_node -> 'children') <> 'array'"));
    expect(sql, contains("jsonb_typeof(p_node -> 'child') = 'object'"));
    expect(sql, contains('jsonb_array_elements(p_node -> \'children\')'));
    expect(sql, contains('v3_condition_ast_contains_executable_key'));
    expect(
      sql,
      contains("ARRAY['script', 'code', 'function', 'expression']"),
    );
    final executableKeyGuard = RegExp(
      r'CREATE OR REPLACE FUNCTION public\.v3_condition_ast_contains_executable_key[\s\S]*?\$\$;',
    ).firstMatch(sql)!.group(0)!;
    expect(
      executableKeyGuard,
      contains('ELSE'),
      reason: 'Scalar JSON nodes must not raise CASE_NOT_FOUND.',
    );
    expect(sql, contains('leaf kinds are approved separately'));
    expect(
      RegExp(r'\bscript\s+(?:TEXT|JSONB|JSON|VARCHAR)', caseSensitive: false)
          .hasMatch(sql),
      isFalse,
      reason: 'Conditions must not gain an executable script field.',
    );
  });

  test('selectors stay generalized and candidates model explicit None safely',
      () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('result_type TEXT NOT NULL'));
    expect(sql, contains('result_kind TEXT NOT NULL'));
    expect(sql, contains("result_kind IN ('value', 'none')"));
    expect(sql, contains('result_id TEXT'));
    expect(
        sql, contains('condition_id TEXT REFERENCES public.v3_conditions(id)'));
    expect(
      sql,
      contains(
        "(result_kind = 'none' AND result_id IS NULL)\n      OR (\n        result_kind = 'value'\n        AND btrim(COALESCE(result_id, '')) <> ''",
      ),
    );
    expect(sql, contains('weight NUMERIC NOT NULL'));
    expect(sql, contains('weight > 0'));
    expect(
        sql, contains("weight::TEXT NOT IN ('NaN', 'Infinity', '-Infinity')"));
    expect(sql, contains('id UUID PRIMARY KEY DEFAULT gen_random_uuid()'));
    expect(sql, contains('UNIQUE (selector_id, ordinal)'));
  });

  test('selectors validate candidate sets and protect authored records', () {
    final sql = migration.readAsStringSync();

    expect(sql, contains('v3_assert_selector_has_candidates'));
    expect(sql,
        contains('CREATE CONSTRAINT TRIGGER v3_selectors_require_candidates'));
    expect(sql, contains('DEFERRABLE INITIALLY DEFERRED'));
    expect(sql, contains('v3_prevent_condition_mutation'));
    expect(sql, contains('v3_prevent_selector_candidate_mutation'));
    expect(sql, contains('v3_limit_selector_mutation'));
    expect(
      sql,
      contains('CREATE POLICY "v3_conditions_authenticated_read"'),
    );
    expect(
      sql,
      contains('CREATE POLICY "v3_selectors_authenticated_read"'),
    );
    expect(
      sql,
      contains('CREATE POLICY "v3_selector_candidates_authenticated_read"'),
    );
    expect(sql, contains('FOR SELECT TO authenticated'));
  });
}
