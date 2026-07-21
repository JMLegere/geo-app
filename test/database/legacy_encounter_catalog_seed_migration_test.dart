import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String sql;

  setUpAll(() {
    sql = File(
      'supabase/migrations/080_legacy_encounter_catalog_seed.sql',
    ).readAsStringSync();
  });

  test('seeds one generalized compatibility Selector and eligibility pair', () {
    expect(sql, contains("'selector:legacy-cell-encounter'"));
    expect(sql, contains("'encounter_definition'"));
    expect(sql, contains("'legacy_encounter_eligible'"));
    expect(sql, contains("'condition:legacy-encounter-eligible'"));
    expect(sql, contains("'condition:legacy-encounter-ineligible'"));
    expect(sql, contains("'kind', 'not'"));
    expect(sql, contains("'none'"));
    expect(
      sql,
      contains(
        "md5('earthnova:legacy-encounter-selector-candidate:none')::uuid",
      ),
    );
  });

  test('matches the live Selector and Encounter schemas exactly', () {
    expect(sql, contains('condition_schema_version'));
    expect(sql, contains('condition_ast'));
    expect(sql, isNot(contains('\n  schema_version,')));
    expect(sql, isNot(contains('\n  ast\n')));
    expect(sql, contains('weight'));
    expect(sql, isNot(contains('relative_weight')));
    expect(sql, contains('encounter_definition_id'));
    expect(sql, contains('display_name'));
    expect(sql, contains('is_automatic'));
    expect(sql, contains('condition_id'));
    expect(sql, contains('kind'));
    expect(sql, isNot(contains('\n  definition_id,')));
    expect(sql, isNot(contains('\n  title,')));
    expect(sql, isNot(contains('\n  automatic,')));
    expect(sql, isNot(contains('\n  outcome_kind,')));
  });

  test('seeds the exact current ComputeEncounter catalog in order', () {
    const slugs = [
      'amberwing_warbler',
      'red_fox',
      'monarch_butterfly',
      'painted_turtle',
      'snowshoe_hare',
      'brook_trout',
      'great_blue_heron',
      'eastern_chipmunk',
    ];

    for (final slug in slugs) {
      expect(sql, contains("'$slug'"));
      expect(sql, contains("'fauna:$slug'"));
    }

    expect(sql, contains("'encounter:fauna:' || slug"));
    expect(
      sql,
      contains("md5('earthnova:legacy-encounter-version:' || slug)::uuid"),
    );
    expect(
      sql,
      contains(
        "md5('earthnova:legacy-encounter-option:' || catalog.slug)::uuid",
      ),
    );
    expect(
      sql,
      contains(
        "md5('earthnova:legacy-encounter-selector-candidate:' || catalog.slug)::uuid",
      ),
    );
    expect(
      RegExp(
        r"\('(?:amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)'",
      ).allMatches(sql).map((match) => match.group(0)).toSet().length,
      8,
    );
  });

  test('authors drafts before immutable children and publishes afterward', () {
    final versionInsert = sql.indexOf(
      'INSERT INTO public.v3_encounter_definition_versions',
    );
    final optionInsert = sql.indexOf('INSERT INTO public.v3_encounter_options');
    final outcomeInsert =
        sql.indexOf('INSERT INTO public.v3_encounter_outcomes');
    final publication = sql.indexOf(
      'public.publish_v3_encounter_definition_version',
    );
    final candidateInsert =
        sql.indexOf('INSERT INTO public.v3_selector_candidates');
    final activation = sql.indexOf("SET status = 'active'");

    expect(
      [
        versionInsert,
        optionInsert,
        outcomeInsert,
        publication,
        candidateInsert
      ],
      everyElement(greaterThanOrEqualTo(0)),
    );
    expect(versionInsert, lessThan(optionInsert));
    expect(optionInsert, lessThan(outcomeInsert));
    expect(outcomeInsert, lessThan(publication));
    expect(candidateInsert, lessThan(activation));
    expect(sql, contains("'draft'"));
    expect(sql, contains('is_implicit'));
  });

  test('every compatibility Encounter generates exactly one Base Item', () {
    expect(sql, contains("'generate_item'"));
    expect(sql, isNot(contains("'reveal_venue'")));
    expect(sql, contains("jsonb_build_object('base_item_id'"));
    expect(sql, isNot(contains('quantity')));
    expect(sql.toLowerCase(), isNot(contains('rarity')));
    expect(sql.toLowerCase(), isNot(contains('script')));
  });

  test('seed is repeat-safe and non-destructive', () {
    expect(sql, contains('ON CONFLICT DO NOTHING'));
    expect(sql, contains('publish_v3_encounter_definition_version'));
    expect(sql, contains('v3_assert_selector_has_candidates'));
    expect(
      RegExp(
        r'\b(delete\s+from|truncate\s+table|drop\s+(table|column))\b',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
    );
    expect(sql, isNot(contains('v3_cell_visits')));
    expect(sql, isNot(contains('UPDATE public.v3_items')));
  });
}
