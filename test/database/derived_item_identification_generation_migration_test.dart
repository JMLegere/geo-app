import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '089_derived_item_identification_generation.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String functionBody(String sql, String functionName) => RegExp(
        'CREATE OR REPLACE FUNCTION public\\.$functionName'
        r'[\s\S]*?\$\$;',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  test(
      'derives all three lifecycle cases from Player Discovery and exact Version properties',
      () {
    final helper = functionBody(
      readMigration(),
      r'v3_item_identification_required\(',
    );

    expect(helper, contains('v3_item_discoveries AS discovery'));
    expect(helper, contains('discovery.user_id = p_user_id'));
    expect(helper, contains('discovery.base_item_id = p_base_item_id'));
    expect(helper, contains('NOT EXISTS ('));
    expect(
      helper,
      contains('v3_base_item_version_variable_properties AS assignment'),
    );
    expect(
      helper,
      contains('assignment.base_item_version_id = p_base_item_version_id'),
    );
    expect(helper, contains(') OR EXISTS ('));

    final trigger = functionBody(
      readMigration(),
      r'v3_derive_item_identification_on_insert\(',
    );
    expect(trigger, contains("NEW.identification_state := 'unidentified'"));
    expect(trigger, contains('NEW.identified_at := NULL'));
    expect(trigger, contains("NEW.identification_state := 'identified'"));
    expect(trigger, contains('NEW.identified_at := now()'));
    expect(
      trigger,
      contains(
          "NEW.display_name := 'Unidentified ' || v_base_item_category || ' specimen'"),
    );
  });

  test(
      'validates and projects from the exact bound Version, never a current Version',
      () {
    final sql = readMigration();
    final helper = functionBody(sql, r'v3_item_identification_required\(');
    final trigger =
        functionBody(sql, r'v3_derive_item_identification_on_insert\(');

    expect(
      helper,
      contains('base_item_version.id = p_base_item_version_id'),
    );
    expect(
      helper,
      contains('base_item_version.base_item_id = p_base_item_id'),
    );
    expect(
        trigger, contains('base_item_version.id = NEW.base_item_version_id'));
    expect(
      trigger,
      contains('base_item_version.base_item_id = NEW.base_item_id'),
    );
    expect(
      trigger,
      isNot(contains('SELECT base_item.category, base_item_version.*')),
    );
    expect(helper, isNot(contains('current_published_version_id')));
    expect(trigger, isNot(contains('current_published_version_id')));
  });

  test(
      'shares the before-insert lifecycle across legacy and authoritative acquisition paths',
      () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains(
        'create trigger v3_items_derive_identification_on_insert before insert on public.v3_items for each row execute function public.v3_derive_item_identification_on_insert()',
      ),
    );
    expect(
      normalized,
      isNot(contains('acquire_v3_legacy_discovery_item(')),
    );
    expect(
      normalized,
      isNot(contains('resolve_v3_encounter_outcomes(')),
    );
  });

  test(
      'preserves hidden canonical sources and promotes their documented precedence',
      () {
    final trigger = functionBody(
      readMigration(),
      r'v3_derive_item_identification_on_insert\(',
    );

    for (final field in <String>[
      'display_name',
      'scientific_name',
      'taxonomic_class',
      'habitats_json',
      'continents_json',
    ]) {
      expect(trigger, contains('NEW.identified_$field'));
    }

    expect(
      trigger,
      contains("v_snapshot ->> 'identified_display_name'"),
    );
    expect(trigger, contains('NULLIF(NEW.identified_display_name, \'\')'));
    expect(trigger, contains('NULLIF(v_base_item_version.display_name, \'\')'));
    expect(trigger, contains('NULLIF(NEW.display_name, \'\')'));
    expect(
      trigger,
      contains("#>> '{legacy_catalog_snapshot,taxonomic_class}'"),
    );
    expect(trigger, contains("#>> '{legacy_item_snapshot,taxonomic_class}'"));
    expect(trigger, contains("#>> '{legacy_catalog_snapshot,habitats}'"));
    expect(trigger, contains("#>> '{legacy_item_snapshot,habitats_json}'"));
    expect(trigger, contains("#>> '{legacy_catalog_snapshot,continents}'"));
    expect(trigger, contains("#>> '{legacy_item_snapshot,continents_json}'"));
    expect(trigger, contains('NEW.display_name := COALESCE('));
    expect(trigger,
        contains('NEW.scientific_name := v_canonical_scientific_name'));
  });

  test(
      'writes only one idempotent automatic receipt and no Discovery, values, or XP',
      () {
    final sql = readMigration();
    final receipt = functionBody(
      sql,
      r'v3_commit_automatic_item_identification\(',
    );

    expect(receipt, contains('v3_item_identification_commits'));
    expect(receipt, contains("'automatic'"));
    expect(receipt, contains("'[]'::jsonb"));
    expect(receipt, contains('NEW.identified_at'));
    expect(receipt, contains('ON CONFLICT (item_id) DO NOTHING'));
    expect(receipt, contains("NEW.identification_state <> 'identified'"));
    expect(receipt, isNot(contains('v3_item_discoveries')));
    expect(receipt, isNot(contains('v3_item_property_values')));
    expect(receipt, isNot(contains('v3_discipline_progress')));

    final normalized = compact(sql).toLowerCase();
    expect(
      normalized,
      contains(
        'create trigger v3_items_commit_automatic_identification_on_insert after insert on public.v3_items for each row execute function public.v3_commit_automatic_item_identification()',
      ),
    );
    expect(
      RegExp(r'insert\s+into\s+public\.v3_item_discoveries').hasMatch(sql),
      isFalse,
    );
    expect(
      RegExp(r'insert\s+into\s+public\.v3_item_property_values').hasMatch(sql),
      isFalse,
    );
    expect(
      RegExp(r'(insert|update)\s+.*v3_discipline_progress').hasMatch(sql),
      isFalse,
    );
  });

  test(
      'replaces only the runtime aggregate read projection with exact item state and revision',
      () {
    final aggregate = functionBody(
      readMigration(),
      r'v3_encounter_runtime_aggregate\(',
    );

    expect(aggregate,
        contains("'identification_state', item.identification_state"));
    expect(aggregate, contains("'identified_at', item.identified_at"));
    expect(aggregate, contains("'base_item_id', item.base_item_id"));
    expect(
      aggregate,
      contains("'base_item_version_id', item.base_item_version_id"),
    );
    expect(
      aggregate,
      contains("'base_item_revision', item_base_item_version.revision"),
    );
    expect(
      aggregate,
      contains('item_base_item_version.id = item.base_item_version_id'),
    );
    expect(
      aggregate,
      contains('item_base_item_version.base_item_id = item.base_item_id'),
    );
  });

  test(
      'does not rewrite existing Items, consult a current Version, or change command grants',
      () {
    final sql = readMigration().toLowerCase();

    expect(sql, isNot(contains('update public.v3_items')));
    expect(sql, isNot(contains('delete from public.v3_items')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('current_published_version_id')));
    expect(
        sql,
        isNot(contains(
            'grant execute on function public.acquire_v3_legacy_discovery_item')));
    expect(
        sql,
        isNot(contains(
            'grant execute on function public.resolve_v3_encounter_outcomes')));
    expect(
        sql,
        contains(
            'revoke all on function public.v3_item_identification_required'));
    expect(
        sql,
        contains(
            'revoke all on function public.v3_derive_item_identification_on_insert'));
    expect(
        sql,
        contains(
            'revoke all on function public.v3_commit_automatic_item_identification'));
  });
}
