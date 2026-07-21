import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '096_restrict_reveal_venue_outcome_reads.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String policyBody(String sql) => RegExp(
        'CREATE POLICY "v3_encounter_outcomes_authenticated_read"'
        r'[\s\S]*?\n  \);',
      ).firstMatch(sql)!.group(0)!;

  test(
      'allows Reveal Venue Outcome reads only for the authenticated Player knowledge',
      () {
    final policy = policyBody(readMigration());

    expect(
      policy,
      contains("kind <> 'reveal_venue'"),
      reason:
          'All non-Reveal Outcome kinds retain their published-content read.',
    );
    expect(policy, contains('FROM public.v3_player_known_venues AS known'));
    expect(policy, contains('known.user_id = auth.uid()'));
    expect(policy, contains("known.venue_id = payload ->> 'venue_id'"));
    expect(
      policy.indexOf("kind <> 'reveal_venue'") <
          policy.indexOf('FROM public.v3_player_known_venues AS known'),
      isTrue,
      reason:
          'Unknown Reveal targets are denied; a knowledge row for auth.uid() is required.',
    );
  });

  test('preserves published and retired reads for non-Reveal Outcomes', () {
    final policy = policyBody(readMigration());

    expect(policy, contains('FROM public.v3_encounter_options AS option'));
    expect(policy,
        contains('JOIN public.v3_encounter_definition_versions AS version'));
    expect(
      policy,
      contains("version.publication_status IN ('published', 'retired')"),
    );
  });

  test('only replaces the authenticated Outcome read policy', () {
    final sql = readMigration();

    expect(
      sql,
      contains(
          'DROP POLICY IF EXISTS "v3_encounter_outcomes_authenticated_read"'),
    );
    expect(sql, contains('ON public.v3_encounter_outcomes'));
    expect(sql, isNot(contains('ALTER TABLE')));
    expect(sql, isNot(contains('GRANT ')));
    expect(sql, isNot(contains('REVOKE ')));
  });
}
