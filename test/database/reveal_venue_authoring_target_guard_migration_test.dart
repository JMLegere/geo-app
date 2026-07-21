import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final encounterMigration = File(
    '${Directory.current.path}/supabase/migrations/'
    '078_encounter_content_and_runtime.sql',
  );
  final guardMigration = File(
    '${Directory.current.path}/supabase/migrations/'
    '095_validate_reveal_venue_outcome_target.sql',
  );

  String read(File migration) {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String function(String sql, String name) => RegExp(
        'CREATE OR REPLACE FUNCTION public\\.$name' r'[\s\S]*?\$\$;',
      ).firstMatch(sql)!.group(0)!;

  String stableTargetValidationBranch(String validator, String kind) => RegExp(
        "IF NEW\\.kind = '$kind' AND NOT EXISTS \\([\\s\\S]*?END IF;",
      ).firstMatch(validator)!.group(0)!;

  test(
      'requires known stable targets when authoring Generate Item and Reveal Venue',
      () {
    final historicalValidator = function(
      read(encounterMigration),
      'v3_validate_encounter_outcome_base_item\\(\\)',
    );
    final validator = function(
      read(guardMigration),
      'v3_validate_encounter_outcome_base_item\\(\\)',
    );

    expect(
      validator,
      contains("IF NEW.kind = 'generate_item' AND NOT EXISTS ("),
    );
    expect(validator, contains('FROM public.v3_base_items'));
    expect(validator, contains("WHERE id = NEW.payload ->> 'base_item_id'"));
    expect(
      validator,
      contains('Generate Item Outcome must reference an existing Base Item %'),
    );
    expect(
      stableTargetValidationBranch(validator, 'generate_item'),
      stableTargetValidationBranch(historicalValidator, 'generate_item'),
      reason:
          'Generate Item target validation must remain byte-for-byte equivalent.',
    );
    expect(
      validator,
      contains("IF NEW.kind = 'reveal_venue' AND NOT EXISTS ("),
    );
    expect(validator, contains('FROM public.v3_venues'));
    expect(validator, contains("WHERE id = NEW.payload ->> 'venue_id'"));
    expect(
      validator,
      contains('Reveal Venue Outcome must reference an existing Venue %'),
    );
    expect(
      RegExp(r"USING ERRCODE = '23503';").allMatches(validator),
      hasLength(2),
      reason:
          'Missing stable Base Item or Venue identities must fail with a foreign-key error.',
    );
  });

  test(
      'permits a known unpublished Venue identity and guards both inserts and updates',
      () {
    final encounterSql = read(encounterMigration);
    final validator = function(
      read(guardMigration),
      'v3_validate_encounter_outcome_base_item\\(\\)',
    );

    expect(validator, isNot(contains('public.v3_venue_versions')));
    expect(validator, isNot(contains('current_published_version_id')));
    expect(validator, isNot(contains('publication_status')));
    expect(
      encounterSql,
      contains(
        'BEFORE INSERT OR UPDATE OF kind, payload ON public.v3_encounter_outcomes',
      ),
    );
    expect(
      encounterSql,
      contains(
          'EXECUTE FUNCTION public.v3_validate_encounter_outcome_base_item();'),
    );
  });

  test(
      'keeps validation helpers private and publication authoring service-only',
      () {
    final sql = read(guardMigration);

    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_base_item()\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
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

  test('is append-only and leaves authoring history unchanged', () {
    final guardSql = read(guardMigration);

    expect(
      sha256.convert(encounterMigration.readAsBytesSync()).toString(),
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
  });
}
