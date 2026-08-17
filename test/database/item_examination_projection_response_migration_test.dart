import 'dart:io';

import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '102_item_examination_projection_response.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String examineBlock(String sql) {
    final match = RegExp(
      r'CREATE\s+OR\s+REPLACE\s+FUNCTION\s+public\.examine_v3_item'
      r'\s*\([\s\S]*?\$\$;',
      caseSensitive: false,
    ).firstMatch(sql);
    expect(match, isNotNull,
        reason: 'Migration 102 must replace examine_v3_item.');
    return match!.group(0)!;
  }

  test('returns the safe Item projection after preserving examination evidence',
      () {
    final examine = examineBlock(readMigration()).toLowerCase();

    expect(
      RegExp(
        r'public\.examine_v3_item\s*\(\s*p_item_id\s+uuid\s*\)',
      ).hasMatch(examine),
      isTrue,
    );
    for (final gate in const <String>[
      'returns jsonb',
      'security definer',
      'set search_path = public',
      'v_user_id uuid := auth.uid()',
      'p_item_id is null',
      'item.id = p_item_id',
      'item.user_id = v_user_id',
      "item.status = 'active'",
      'for update',
      'on conflict (user_id, base_item_id) do nothing',
      'select entry.*',
      'return public.v3_safe_item_projection(v_item)',
    ]) {
      expect(examine, contains(gate));
    }
    expect(
      examine.indexOf('return public.v3_safe_item_projection(v_item)'),
      greaterThan(examine.indexOf('select entry.*')),
      reason:
          'Both first and repeated calls project the owned Item after journal evidence exists.',
    );
    expect(examine, isNot(contains('jsonb_build_object')));
    expect(examine, isNot(contains("'examined_item_id'")));
  });

  test('keeps Item state and property values untouched', () {
    final normalized = compact(readMigration()).toLowerCase();

    for (final forbidden in const <String>[
      'create table',
      'update public.v3_items',
      'insert into public.v3_items',
      'delete from public.v3_items',
      'update public.v3_item_property_values',
      'insert into public.v3_item_property_values',
      'delete from public.v3_item_property_values',
      'drop table',
      'truncate table',
    ]) {
      expect(normalized, isNot(contains(forbidden)));
    }
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

  test('the examined projection is parseable by ItemDto', () {
    final item = ItemDto.fromJson({
      'id': '123e4567-e89b-12d3-a456-426614174001',
      'definition_id': 'species.panthera_leo.12345678',
      'base_item_id': 'fauna:panthera_leo',
      'base_item_version_id': '123e4567-e89b-12d3-a456-426614174002',
      'display_name': 'Lion',
      'scientific_name': 'Panthera leo',
      'category': 'fauna',
      'rarity': 'EN',
      'acquired_at': '2026-01-01T00:00:00.000Z',
      'status': 'active',
      'habitats_json': '["Savanna"]',
      'continents_json': '["Africa"]',
      'identification_state': 'unidentified',
      'examination_state': 'examined',
      'examined_at': '2026-01-01T00:00:00.000Z',
    });

    expect(item.id, '123e4567-e89b-12d3-a456-426614174001');
    expect(item.baseItemId, 'fauna:panthera_leo');
    expect(item.identificationState, 'unidentified');
    expect(item.examinationState, 'examined');
    expect(item.identifiedAt, isNull);
  });
}
