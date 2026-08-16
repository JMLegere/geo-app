import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '099_pending_present_encounter.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String readFunction(String sql) {
    final match = RegExp(
      r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.'
      r'read_v3_pending_encounter_for_cell\s*\([\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(sql);
    expect(match, isNotNull);
    return match!.group(0)!;
  }

  test(
      'publishes an immutable manual red fox revision with one visible outcome',
      () {
    final sql = readMigration();

    expect(
      RegExp(
        r"INSERT\s+INTO\s+public\.v3_encounter_definition_versions\b"
        r"[\s\S]*?\(\s*[^,]+,\s*'encounter:fauna:red_fox'\s*,\s*2\s*,"
        r"\s*'draft'\s*,\s*[^,]+,\s*FALSE\b",
        caseSensitive: false,
      ).hasMatch(sql),
      isTrue,
    );
    expect(sql, contains('INSERT INTO public.v3_encounter_options'));
    expect(sql, contains('is_implicit'));
    expect(
      RegExp(r'\bFALSE\b', caseSensitive: false).allMatches(sql).length,
      greaterThanOrEqualTo(2),
      reason: 'The revision is manual and its sole Option is visible.',
    );
    expect(sql, contains('INSERT INTO public.v3_encounter_outcomes'));
    expect(sql, contains("'generate_item'"));
    expect(sql, contains("'base_item_id', 'fauna:red_fox'"));
    expect(sql, contains('publish_v3_encounter_definition_version'));
  });

  test('reads only the authenticated owner’s latest pending exact version', () {
    final function = readFunction(readMigration());

    expect(
      RegExp(
        r'read_v3_pending_encounter_for_cell\s*\(\s*\w+\s+TEXT\s*\)',
        caseSensitive: false,
      ).hasMatch(function),
      isTrue,
    );
    expect(function, contains('RETURNS JSONB'));
    expect(function, contains('SECURITY DEFINER'));
    expect(function, contains('auth.uid()'));
    expect(function, contains('v_user_id IS NULL'));
    expect(function, contains('cell_visit.user_id = v_user_id'));
    expect(function, contains('cell_visit.cell_id = p_cell_id'));
    expect(function, contains("encounter.resolution_status = 'pending'"));
    expect(
      RegExp(
        r'ORDER\s+BY\s+cell_visit\.visited_at\s+DESC[\s\S]*?LIMIT\s+1',
        caseSensitive: false,
      ).hasMatch(function),
      isTrue,
    );
    expect(
      RegExp(
        r'encounter_version\.id\s*=\s*'
        r'encounter\.encounter_definition_version_id',
        caseSensitive: false,
      ).hasMatch(function),
      isTrue,
    );
    expect(function, contains("'encounter_definition_version_id'"));
    expect(function, contains("'revision'"));
    expect(function, contains("'display_name'"));
    expect(function, contains("'options'"));
    expect(
      RegExp(r'jsonb_agg\([\s\S]*?ORDER\s+BY\s+option\.ordinal',
              caseSensitive: false)
          .hasMatch(function),
      isTrue,
    );
    expect(function, contains("'id', option.id"));
    expect(function, contains("'ordinal', option.ordinal"));
    expect(function, contains("'display_name', option.display_name"));
    expect(function, isNot(contains('current_published_version_id')));
  });

  test('exposes a read-only RPC and makes the migration non-destructive', () {
    final sql = readMigration();
    final function = readFunction(sql);

    expect(
      RegExp(
        r'REVOKE\s+ALL\s+ON\s+FUNCTION\s+public\.'
        r'read_v3_pending_encounter_for_cell\s*\(\s*TEXT\s*\)\s+FROM\s+PUBLIC',
        caseSensitive: false,
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'GRANT\s+EXECUTE\s+ON\s+FUNCTION\s+public\.'
        r'read_v3_pending_encounter_for_cell\s*\(\s*TEXT\s*\)\s+TO\s+authenticated',
        caseSensitive: false,
      ).hasMatch(sql),
      isTrue,
    );
    expect(
      RegExp(
        r'^\s*(?:UPDATE\b|DELETE\s+FROM\b|TRUNCATE\b)',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(sql),
      isFalse,
    );
    expect(
      RegExp(
        r'^\s*(?:INSERT\b|UPDATE\b|DELETE\b)',
        caseSensitive: false,
        multiLine: true,
      ).hasMatch(function),
      isFalse,
    );
    expect(
      RegExp(
        r'\b(?:resolve_v3_|acquire_v3_|generate_v3_|identify_v3_)\w*\s*\(',
        caseSensitive: false,
      ).hasMatch(function),
      isFalse,
    );
  });
}
