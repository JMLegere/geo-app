import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '100_item_examination_service.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String functionBlock(String sql, String name) {
    final match = RegExp(
      r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.' +
          name +
          r'\s*\([\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(sql);
    expect(match, isNotNull, reason: 'Migration 100 must define $name.');
    return match!.group(0)!;
  }

  test(
      'adds an immutable owner and Base Item examination journal with backfill',
      () {
    final sql = readMigration();
    final normalized = compact(sql).toLowerCase();

    expect(
      normalized,
      contains(
        'create table if not exists public.v3_player_base_item_journal_entries',
      ),
    );
    for (final column in const <String>[
      'user_id uuid not null',
      'base_item_id text not null',
      'examined_at timestamptz not null',
    ]) {
      expect(normalized, contains(column));
    }
    expect(
      RegExp(
        r'create trigger \w+ before update or delete on public\.v3_player_base_item_journal_entries',
      ).hasMatch(normalized),
      isTrue,
      reason: 'Examination evidence is append-only.',
    );
    expect(
      normalized,
      contains("item.identification_state = 'identified'"),
      reason: 'Existing identified Items are the only knowledge backfill.',
    );
    expect(
      normalized,
      contains('insert into public.v3_player_base_item_journal_entries'),
    );
  });

  test('keeps the journal private and command-owned', () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains(
        'alter table public.v3_player_base_item_journal_entries enable row level security',
      ),
    );
    expect(
      normalized,
      contains(
        'revoke all on table public.v3_player_base_item_journal_entries '
        'from public, anon, authenticated',
      ),
    );
    expect(
      normalized,
      isNot(
        contains(
            'grant insert on table public.v3_player_base_item_journal_entries'),
      ),
    );
  });

  test('examination is an authenticated, owned, active, idempotent command',
      () {
    final examine =
        functionBlock(readMigration(), 'examine_v3_item').toLowerCase();
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      RegExp(
        r'public\.examine_v3_item\s*\(\s*p_item_id\s+uuid\s*\)',
        caseSensitive: false,
      ).hasMatch(readMigration()),
      isTrue,
      reason:
          'The command accepts only the Item identity; examination evidence is server-derived.',
    );
    expect(examine, contains('p_item_id uuid'));
    expect(examine, contains('security definer'));
    expect(examine, contains('set search_path = public'));
    expect(examine, contains('v_user_id uuid := auth.uid()'));
    expect(examine, contains('p_item_id is null'));
    expect(examine, contains('item.id = p_item_id'));
    expect(examine, contains('item.user_id = v_user_id'));
    expect(examine, contains("item.status = 'active'"));
    expect(examine, contains('for update'));
    expect(examine, contains('v3_player_base_item_journal_entries'));
    expect(
      examine,
      anyOf(
          contains('on conflict'), contains('if found'), contains('if exists')),
      reason: 'Repeated examination must return the durable original evidence.',
    );
    expect(
      normalized,
      contains(
          'revoke all on function public.examine_v3_item(uuid) from public, anon'),
    );
    expect(
      normalized,
      contains(
          'grant execute on function public.examine_v3_item(uuid) to authenticated'),
    );
  });

  test('examination never mutates Item identity, state, or property values',
      () {
    final examine =
        functionBlock(readMigration(), 'examine_v3_item').toLowerCase();

    for (final forbidden in const <String>[
      'update public.v3_items',
      'insert into public.v3_items',
      'delete from public.v3_items',
      'update public.v3_item_property_values',
      'insert into public.v3_item_property_values',
      'delete from public.v3_item_property_values',
    ]) {
      expect(examine, isNot(contains(forbidden)));
    }
  });

  test(
      'projects unexamined, examined, and identified Items without leaking values',
      () {
    final projection =
        functionBlock(readMigration(), 'v3_safe_item_projection').toLowerCase();

    expect(projection, contains('v3_player_base_item_journal_entries'));
    expect(projection, contains("'unexamined'"));
    expect(projection, contains("'examined'"));
    expect(projection, contains("p_item.identification_state = 'identified'"));
    expect(projection, contains("'identification_state', 'unidentified'"));
    expect(projection, contains("'examination_state'"));
    expect(projection, contains("'examined_at'"));
    expect(projection, contains("'base_item_id'"));
    expect(projection, contains("'base_item_version_id'"));
    for (final field in const <String>[
      "'definition_id'",
      "'base_item_id'",
      "'base_item_version_id'",
      "'scientific_name'",
      "'rarity'",
      "'icon_url'",
      "'icon_url_frame2'",
      "'art_url'",
      "'taxonomic_class'",
      "'habitats_json'",
      "'continents_json'",
    ]) {
      expect(
        projection.split(field).length,
        3,
        reason:
            'Examined and identified Items share their complete Base Item content.',
      );
    }
    final unexamined = projection.substring(projection.lastIndexOf('else'));
    for (final maskedField in const <String>[
      "'definition_id'",
      "'base_item_id'",
      "'base_item_version_id'",
      "'scientific_name'",
      "'rarity'",
      "'icon_url'",
      "'icon_url_frame2'",
      "'art_url'",
      "'taxonomic_class'",
      "'habitats_json'",
      "'continents_json'",
    ]) {
      expect(
        unexamined,
        isNot(contains(maskedField)),
        reason: 'Unexamined Items retain their masked projection.',
      );
    }
    expect(
      projection,
      isNot(contains("'property_values'")),
      reason: 'Pack never exposes mutable property values.',
    );
    expect(
      projection,
      contains("when p_item.identification_state = 'identified' then"),
      reason: 'Identification remains distinct from examination.',
    );
  });

  test(
      'returns every active Pack Item newest first through the safe projection',
      () {
    final pack =
        functionBlock(readMigration(), 'fetch_v3_pack_items').toLowerCase();

    expect(pack, contains('public.v3_safe_item_projection(item)'));
    expect(pack, contains('item.user_id = v_user_id'));
    expect(pack, contains("item.status = 'active'"));
    expect(pack, contains('order by item.acquired_at desc'));
    expect(pack, isNot(contains('limit ')));
  });

  test('seeds the Identification Service and Rowan current revision two', () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(normalized, contains("'service:identify_item_properties'"));
    expect(normalized, contains('insert into public.v3_service_versions'));
    expect(
      RegExp(
        r"service:identify_item_properties'\s*,\s*1\s*,\s*'draft'",
      ).hasMatch(normalized),
      isTrue,
    );
    expect(normalized,
        contains("md5('earthnova:villager-version:rowan:2')::uuid"));
    expect(
      RegExp(r"villager:rowan'\s*,\s*2\s*,\s*'draft'").hasMatch(normalized),
      isTrue,
    );
    expect(normalized, contains("'service:release_to_wild'"));
    expect(normalized,
        contains('insert into public.v3_villager_version_services'));
    expect(normalized, contains('publish_v3_villager_version'));
  });

  test(
      'preparation requires an owned active examined Item and current known service access',
      () {
    final prepare =
        functionBlock(readMigration(), 'prepare_v3_item_identification')
            .toLowerCase();

    expect(prepare, contains('v_user_id uuid := auth.uid()'));
    expect(prepare, contains('item.id = p_item_id'));
    expect(prepare, contains('item.user_id = v_user_id'));
    expect(prepare, contains("item.status = 'active'"));
    expect(prepare, contains('v3_player_base_item_journal_entries'));
    expect(prepare, contains('v3_player_known_villagers'));
    expect(prepare, contains('v3_villager_versions'));
    expect(prepare, contains('villager.current_published_version_id'));
    expect(prepare, contains('v3_villager_version_services'));
    expect(prepare, contains('v3_services'));
    expect(prepare, contains('service.current_published_version_id'));
    expect(prepare, contains('v3_service_versions'));
    expect(prepare, contains("'service_access'"));
    expect(prepare, isNot(contains('v3_venue_visits')));
  });

  test('preparation returns exact service access in its plan', () {
    final prepare =
        functionBlock(readMigration(), 'prepare_v3_item_identification')
            .toLowerCase();

    for (final field in const <String>[
      "'service_access'",
      "'villager_id'",
      "'villager_display_name'",
      "'service_id'",
      "'service_version_id'",
      "'service_version_revision'",
      "'service_display_name'",
    ]) {
      expect(prepare, contains(field));
    }
    expect(prepare, contains("'service_access', jsonb_build_object("));
    expect(prepare, isNot(contains("'identification_service_access'")));
  });

  test('the new commit binds the Dart RPC inputs to current service access',
      () {
    final commits = RegExp(
      r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.identify_v3_item'
      r'\s*\([\s\S]*?\$\$;',
      caseSensitive: false,
    )
        .allMatches(readMigration())
        .map((match) => match.group(0)!.toLowerCase())
        .toList();
    final identify = commits.firstWhere(
      (commit) => commit.contains('p_expected_service_id'),
      orElse: () => '',
    );

    expect(identify, isNotEmpty,
        reason: 'Migration 100 must add the service-bound commit overload.');
    expect(
      RegExp(
        r'public\.identify_v3_item\s*\(\s*'
        r'p_item_id\s+uuid\s*,\s*'
        r'p_expected_base_item_id\s+text\s*,\s*'
        r'p_expected_base_item_version_id\s+uuid\s*,\s*'
        r'p_expected_service_id\s+text\s*,\s*'
        r'p_expected_service_version_id\s+uuid\s*,\s*'
        r'p_expected_villager_id\s+text\s*,\s*'
        r'p_property_resolutions\s+jsonb\s*\)',
      ).hasMatch(identify),
      isTrue,
      reason: 'The bound SQL overload must match the Dart RPC payload exactly.',
    );
    expect(identify, isNot(contains('p_expected_villager_version_id')));
    expect(identify, contains('v3_player_base_item_journal_entries'));
    expect(identify, contains('v3_player_known_villagers'));
    expect(identify, contains('villager.current_published_version_id'));
    expect(identify,
        contains("villager_version.publication_status = 'published'"));
    expect(identify, contains('service.current_published_version_id'));
    expect(identify, contains('return public.v3_identify_v3_item_core('));
    expect(identify, isNot(contains('v3_venue_visits')));
  });

  test('grants only the compatibility and bound identification signatures', () {
    final normalized = compact(readMigration()).toLowerCase();

    expect(
      normalized,
      contains('identify_v3_item(uuid, text, uuid, jsonb)'),
      reason: 'Existing clients must retain a safe compatibility signature.',
    );
    for (final clause in const <String>[
      'revoke all on function public.identify_v3_item(uuid, text, uuid, jsonb) from public, anon',
      'grant execute on function public.identify_v3_item(uuid, text, uuid, jsonb) to authenticated',
      'revoke all on function public.identify_v3_item( uuid, text, uuid, text, uuid, text, jsonb ) from public, anon',
      'grant execute on function public.identify_v3_item( uuid, text, uuid, text, uuid, text, jsonb ) to authenticated',
    ]) {
      expect(normalized, contains(clause));
    }
    expect(
      normalized,
      isNot(
        contains(
            'identify_v3_item(uuid, text, uuid, text, uuid, text, uuid, jsonb)'),
      ),
      reason: 'Villager version is server-validated rather than a wire input.',
    );
  });

  test('is additive and contains no destructive database or Item-property SQL',
      () {
    final normalized = compact(readMigration()).toLowerCase();

    for (final forbidden in const <String>[
      'drop table',
      'truncate ',
      'alter table public.v3_items drop',
      'alter table public.v3_item_property_values drop',
      'delete from public.v3_items',
      'delete from public.v3_item_property_values',
      'update public.v3_items',
      'update public.v3_item_property_values',
    ]) {
      expect(normalized, isNot(contains(forbidden)));
    }
  });
}
