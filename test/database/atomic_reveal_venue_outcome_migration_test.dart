import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '093_atomic_reveal_venue_outcome.sql',
  );

  String sql() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String function(String value, String name) => RegExp(
        'CREATE OR REPLACE FUNCTION public\\.$name' r'[\s\S]*?\$\$;',
      ).firstMatch(value)!.group(0)!;

  test('adds nullable exact Venue bindings without rewriting old results', () {
    final value = sql();
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

    expect(value, contains('ADD COLUMN IF NOT EXISTS resolved_venue_id TEXT'));
    expect(
      value,
      contains('ADD COLUMN IF NOT EXISTS resolved_venue_version_id UUID'),
    );
    expect(
      normalized,
      contains(
        'foreign key (resolved_venue_id, resolved_venue_version_id) '
        'references public.v3_venue_versions(venue_id, id)',
      ),
    );
    expect(
      normalized,
      contains('on update restrict on delete restrict not valid'),
    );
    expect(
      value,
      contains(
        'DROP CONSTRAINT IF EXISTS '
        'v3_encounter_outcome_results_kind_specific_binding_check',
      ),
    );
    expect(value, contains("outcome_kind = 'generate_item'"));
    expect(value, contains("outcome_kind = 'reveal_venue'"));
    expect(value, contains('resolved_venue_id IS NULL'));
    expect(value, contains('resolved_venue_version_id IS NOT NULL'));
    expect(value, isNot(contains('DROP TABLE')));
    expect(value, isNot(contains('TRUNCATE')));
    expect(value,
        isNot(contains('DELETE FROM public.v3_encounter_outcome_results')));
  });

  test(
      'replaces result and known-state validation with exact immutable bindings',
      () {
    final value = sql();
    final resultValidation =
        function(value, 'v3_validate_encounter_outcome_result\\(\\)');
    final knownValidation =
        function(value, 'v3_validate_known_venue_reveal_provenance\\(\\)');

    expect(
      value,
      contains(
          'DROP TRIGGER IF EXISTS v3_encounter_outcome_results_validate_binding'),
    );
    expect(value, contains('resolved_venue_id, resolved_venue_version_id'));
    expect(resultValidation, contains("outcome.payload ->> 'venue_id'"));
    expect(
        resultValidation, contains('version.venue_id = NEW.resolved_venue_id'));
    expect(
      resultValidation,
      contains("version.publication_status = 'published'"),
    );
    expect(
      resultValidation,
      contains(
          'Reveal Venue Outcome Result must preserve its exact published Venue Version'),
    );

    expect(knownValidation, contains('result.resolved_venue_id'));
    expect(knownValidation, contains('result.resolved_venue_version_id'));
    expect(knownValidation, contains("outcome.payload ->> 'venue_id'"));
    expect(
      knownValidation,
      contains(
          'v_result_venue_version_id IS DISTINCT FROM NEW.first_venue_version_id'),
    );
    expect(knownValidation,
        contains('v_result_user_id IS DISTINCT FROM NEW.user_id'));
    expect(knownValidation, isNot(contains('current_published_version_id')));
  });

  test('prevalidates a locked, ordered mixed Outcome plan before any mutation',
      () {
    final command = function(sql(), 'resolve_v3_encounter_outcomes\\(');
    final plan = command.substring(
      command.indexOf('-- Lock every selected ordered Outcome first.'),
      command.indexOf('IF v_failure_code IS NOT NULL THEN'),
    );
    final commit =
        command.substring(command.indexOf('BEGIN\n    -- The nested'));

    expect(
        plan, contains('ORDER BY outcome.ordinal\n    FOR UPDATE OF outcome'));
    expect(
        plan, contains('ORDER BY base_item.id\n    FOR UPDATE OF base_item'));
    expect(plan, contains('ORDER BY venue.id\n    FOR UPDATE OF venue'));
    expect(plan, contains("v_outcome.kind = 'generate_item'"));
    expect(plan, contains("v_outcome.kind = 'reveal_venue'"));
    expect(plan, contains('v_base_item.current_published_version_id'));
    expect(plan, contains('v_venue.current_published_version_id'));
    expect(plan, contains("venue_version.publication_status = 'published'"));
    expect(plan, contains('FOR UPDATE;'));
    expect(plan, contains("'base_item_version_id', v_base_item_version.id"));
    expect(plan, contains("'venue_version_id', v_venue_version.id"));
    expect(plan, contains('v_plan := v_plan || jsonb_build_object'));

    expect(commit,
        contains('v_plan_entry := v_plan -> (v_outcome.ordinal::TEXT)'));
    expect(commit, contains('Encounter Outcome execution plan is incomplete'));
    expect(
      command.indexOf('-- Lock every selected ordered Outcome first.'),
      lessThan(command.indexOf("SET resolution_status = 'resolved'")),
    );
  });

  test(
      'commits exactly one ordered result per Outcome and first-known Venue evidence',
      () {
    final command = function(sql(), 'resolve_v3_encounter_outcomes\\(');
    final commit =
        command.substring(command.indexOf('BEGIN\n    -- The nested'));
    final reveal = commit.substring(
      commit.indexOf("ELSIF v_outcome.kind = 'reveal_venue' THEN"),
      commit.indexOf(
          "      ELSE\n        RAISE EXCEPTION 'Encounter Outcome execution plan has"),
    );

    expect(reveal, contains('INSERT INTO public.v3_encounter_outcome_results'));
    expect(reveal, contains('RETURNING id INTO v_result_id'));
    expect(reveal, contains('INSERT INTO public.v3_player_known_venues'));
    expect(reveal, contains('first_venue_version_id'));
    expect(reveal, contains('reveal_outcome_result_id'));
    expect(reveal, contains('ON CONFLICT (user_id, venue_id) DO NOTHING'));
    expect(reveal, isNot(contains('UPDATE public.v3_player_known_venues')));
    expect(reveal, isNot(contains('v3_items')));
    expect(reveal, isNot(contains('v3_venue_visits')));
    expect(reveal, isNot(contains('v3_player_known_villagers')));
    expect(command, contains('v_result_count <> v_outcome_count'));
    expect(command, contains('SELECT outcome.ordinal'));
    expect(command, contains('EXCEPT'));
    expect(command, contains('SELECT result.outcome_ordinal'));
    expect(command, contains('Encounter Outcome Result set is incomplete'));
  });

  test(
      'rolls back mixed effects before failed terminal evidence and retries are inert',
      () {
    final command = function(sql(), 'resolve_v3_encounter_outcomes\\(');
    final commit =
        command.substring(command.indexOf('BEGIN\n    -- The nested'));
    final failedTerminal = command.substring(
      command.lastIndexOf('IF v_failure_code IS NOT NULL THEN'),
    );

    expect(command, contains("v_encounter.resolution_status = 'resolved'"));
    expect(command, contains("v_encounter.resolution_status = 'failed'"));
    expect(command, contains('RETURN public.v3_encounter_runtime_aggregate'));
    expect(
      command,
      contains(
        'The nested exception block rolls back every Item, Outcome Result, and\n'
        '    -- known Venue before the outer block stores terminal failure evidence.',
      ),
    );
    expect(command, contains('EXCEPTION WHEN OTHERS THEN'));
    expect(command, contains("v_failure_code := 'outcome_commit_failed'"));
    expect(command, contains("SET resolution_status = 'failed'"));
    expect(
      command.indexOf("v_encounter.resolution_status = 'resolved'"),
      lessThan(commit.indexOf('INSERT INTO public.v3_player_known_venues') +
          command.indexOf('BEGIN\n    -- The nested')),
    );
    expect(
      command.substring(0, command.indexOf('BEGIN\n    -- The nested')),
      isNot(contains('INSERT INTO public.v3_player_known_venues')),
    );
    expect(
      failedTerminal,
      isNot(contains('INSERT INTO public.v3_player_known_venues')),
    );
    expect(command, isNot(contains('unsupported_reveal_venue')));
    expect(command.toLowerCase(), isNot(contains('rarity')));
  });

  test(
      'aggregate has strict exact Venue fields and returns existing known evidence',
      () {
    final aggregate = function(sql(), 'v3_encounter_runtime_aggregate\\(');

    for (final key in <String>[
      "'resolved_venue_id', result.resolved_venue_id",
      "'resolved_venue_version_id', result.resolved_venue_version_id",
      "'resolved_venue_revision', resolved_venue_version.revision",
      "'known_at', known.known_at",
    ]) {
      expect(aggregate, contains(key));
    }
    expect(
      aggregate,
      contains('LEFT JOIN public.v3_venue_versions AS resolved_venue_version'),
    );
    expect(
      aggregate,
      contains('LEFT JOIN public.v3_player_known_venues AS known'),
    );
    expect(aggregate, contains('known.user_id = cell_visit.user_id'));
    expect(aggregate, contains('known.venue_id = result.resolved_venue_id'));
    expect(aggregate, isNot(contains('current_published_version_id')));
  });

  test('keeps helpers private and only the authoritative command callable', () {
    final value = sql();

    expect(
      value,
      contains(
        'REVOKE ALL ON FUNCTION public.v3_validate_encounter_outcome_result()\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      value,
      contains(
        'REVOKE ALL ON FUNCTION public.v3_validate_known_venue_reveal_provenance()\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      value,
      contains(
        'REVOKE ALL ON FUNCTION public.v3_encounter_runtime_aggregate(UUID)\n'
        '  FROM PUBLIC, anon, authenticated;',
      ),
    );
    expect(
      value,
      contains(
        'REVOKE ALL ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)\n'
        '  FROM PUBLIC, anon;',
      ),
    );
    expect(
      value,
      contains(
        'GRANT EXECUTE ON FUNCTION public.resolve_v3_encounter_outcomes(UUID, UUID)\n'
        '  TO authenticated;',
      ),
    );
  });
}
