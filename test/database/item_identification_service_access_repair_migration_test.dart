import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '105_fix_identification_service_villager_projection.sql',
  );

  String readMigration() {
    expect(
      migration.existsSync(),
      isTrue,
      reason: 'Migration 105 must repair the live Identification preparation.',
    );
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('reads the Villager display name from the published Version', () {
    final sql = compact(readMigration()).toLowerCase();

    expect(
      sql,
      contains('villager_version.display_name as villager_display_name'),
    );
    expect(
      sql,
      isNot(contains('villager.display_name as villager_display_name')),
      reason: 'v3_villagers owns identity, not versioned display content.',
    );
  });

  test('preserves the authenticated current-service preparation boundary', () {
    final sql = compact(readMigration()).toLowerCase();

    for (final clause in const <String>[
      'create or replace function public.prepare_v3_item_identification',
      'security definer',
      'set search_path = public',
      'v3_player_base_item_journal_entries',
      'v3_player_known_villagers',
      'villager.current_published_version_id',
      "villager_version.publication_status = 'published'",
      'v3_villager_version_services',
      'service.current_published_version_id',
      "service_version.publication_status = 'published'",
      "'service_access'",
      "'villager_display_name'",
      'grant execute on function public.prepare_v3_item_identification(uuid) to authenticated',
    ]) {
      expect(sql, contains(clause));
    }
  });

  test('repair is additive and leaves player and authored data untouched', () {
    final sql = compact(readMigration()).toLowerCase();

    for (final forbidden in const <String>[
      'drop table',
      'drop column',
      'truncate ',
      'delete from ',
      'update public.',
      'insert into ',
      'alter table ',
    ]) {
      expect(sql, isNot(contains(forbidden)));
    }
  });
}
