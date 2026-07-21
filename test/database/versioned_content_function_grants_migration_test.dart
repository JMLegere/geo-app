import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/082_lock_down_versioned_content_function_grants.sql',
  ).readAsStringSync();
  final normalizedSql = sql.replaceAll(RegExp(r'\s+'), ' ');

  test('publication commands stay service-role only', () {
    expect(sql, contains('publish_v3_base_item_version(TEXT, UUID)'));
    expect(
        sql, contains('publish_v3_encounter_definition_version(TEXT, UUID)'));
    expect(sql, contains('FROM PUBLIC, anon, authenticated'));
    expect(sql, contains('TO service_role'));
  });

  test('Encounter commands expose only authenticated execution', () {
    expect(
      normalizedSql,
      contains(
        'resolve_v3_cell_visit_encounter(UUID, TEXT, UUID, UUID) FROM PUBLIC, anon',
      ),
    );
    expect(
      normalizedSql,
      contains('resolve_v3_encounter_outcomes(UUID, UUID) FROM PUBLIC, anon'),
    );
    expect(sql, contains('TO authenticated'));
  });

  test('Encounter helper functions are not remotely executable', () {
    expect(
      normalizedSql,
      contains(
        'v3_encounter_runtime_aggregate(UUID) FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(
      normalizedSql,
      contains(
        'v3_validate_encounter_outcome_result() FROM PUBLIC, anon, authenticated',
      ),
    );
    expect(
      normalizedSql,
      contains(
        'v3_limit_encounter_mutation() FROM PUBLIC, anon, authenticated',
      ),
    );
  });

  test('grant repair changes no durable rows or schema shape', () {
    expect(
      RegExp(
        r'\b(insert\s+into|update\s+public|delete\s+from|truncate\s+table|drop\s+(table|column))\b',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
    );
  });
}
