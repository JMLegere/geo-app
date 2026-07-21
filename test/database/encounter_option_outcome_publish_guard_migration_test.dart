import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final historicalMigration = File(
    '${Directory.current.path}/supabase/migrations/'
    '078_encounter_content_and_runtime.sql',
  );
  final guardMigration = File(
    '${Directory.current.path}/supabase/migrations/'
    '094_require_encounter_option_outcomes_for_publication.sql',
  );

  String read(File migration) {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String function(String sql, String name) => RegExp(
        'CREATE OR REPLACE FUNCTION public\\.$name' r'[\s\S]*?\$\$;',
      ).firstMatch(sql)!.group(0)!;

  test(
      'publication rejects empty owned Options before changing publication state',
      () {
    final historicalSql = read(historicalMigration);
    final guardSql = read(guardMigration);
    final validator = function(
      guardSql,
      'v3_validate_automatic_encounter_options\\(',
    );
    final publishCommand = function(
      historicalSql,
      'publish_v3_encounter_definition_version\\(',
    );

    expect(
      validator,
      contains('FROM public.v3_encounter_options AS option'),
    );
    expect(
      validator,
      contains('option.encounter_definition_version_id = p_version_id'),
    );
    expect(
      validator,
      contains('FROM public.v3_encounter_outcomes AS outcome'),
    );
    expect(
      validator,
      contains('outcome.encounter_option_id = option.id'),
    );
    expect(
      validator,
      contains(
          'Encounter Definition Version % Option % must have at least one Outcome'),
    );
    expect(validator, contains("USING ERRCODE = '23514'"));
    expect(
      publishCommand.indexOf(
        'PERFORM public.v3_validate_automatic_encounter_options(p_version_id, TRUE);',
      ),
      lessThan(publishCommand
          .indexOf('UPDATE public.v3_encounter_definition_versions')),
      reason:
          'The publish command must validate before retiring or publishing Versions.',
    );
  });

  test(
      'publication still permits Options with Outcomes and preserves publication grants',
      () {
    final validator = function(
      read(guardMigration),
      'v3_validate_automatic_encounter_options\\(',
    );
    final sql = read(guardMigration);

    expect(validator, contains('IF p_require_options THEN'));
    expect(validator, contains('NOT EXISTS ('));
    expect(validator, contains('IF FOUND THEN'));
    expect(
      validator,
      contains('WHERE outcome.encounter_option_id = option.id'),
      reason:
          'The rejection predicate applies only to Options lacking Outcomes.',
    );
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.publish_v3_encounter_definition_version(TEXT, UUID)\n'
        '  TO service_role;',
      ),
    );
  });

  test(
      'uses an additive migration without changing historical or unrelated behavior',
      () {
    final historicalSql = read(historicalMigration);
    final guardSql = read(guardMigration);

    expect(
      sha256.convert(historicalMigration.readAsBytesSync()).toString(),
      '0669bfbeeea7db68d828abb68fdd2b93894b76965ccd6ca581c30a0b76789abb',
      reason: 'Migration 078 is historical and must remain unchanged.',
    );
    expect(
      RegExp(
        r'\b(create\s+or\s+replace\s+function|revoke\s+all\s+on\s+function|grant\s+execute\s+on\s+function)\b',
        caseSensitive: false,
      ).allMatches(guardSql),
      isNotEmpty,
    );
    expect(
      RegExp(
        r'\b(create\s+table|alter\s+table|insert\s+into|update\s+public|delete\s+from|truncate\s+table|drop\s+(table|column))\b',
        caseSensitive: false,
      ).hasMatch(guardSql),
      isFalse,
    );
    expect(historicalSql, contains('v3_validate_automatic_encounter_options'));
  });
}
