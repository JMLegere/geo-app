import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '091_identification_runtime_security_cutover.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('keeps authoritative Identification commands executable', () {
    final sql = compact(readMigration()).toLowerCase();

    expect(
      sql,
      contains(
        'grant execute on function public.'
        'prepare_v3_item_identification(uuid) to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.'
        'identify_v3_item(uuid, text, uuid, jsonb) to authenticated',
      ),
    );
    expect(
      sql,
      contains(
        "has_function_privilege( 'authenticated', "
        "'public.identify_v3_item(uuid,text,uuid,jsonb)', 'execute' )",
      ),
    );
  });

  test('closes the temporary direct Item update compatibility path', () {
    final sql = compact(readMigration()).toLowerCase();

    expect(
      sql,
      contains(
          'revoke update on table public.v3_items from public, anon, authenticated'),
    );
    expect(
      sql,
      contains('drop policy if exists v3_items_update_own on public.v3_items'),
    );
    expect(sql, contains('v3_items_update_own'));
    expect(sql, isNot(contains('create policy v3_items_update_own')));
  });

  test('retains command-owned create and read boundaries', () {
    final sql = compact(readMigration()).toLowerCase();

    expect(
      sql,
      contains(
        'grant execute on function public.'
        'acquire_v3_legacy_discovery_item(',
      ),
    );
    expect(
      sql,
      contains(
        'text, text, text, text, text, text, text, jsonb, jsonb, '
        'text, timestamptz, text, text, text, jsonb, jsonb, text',
      ),
    );
    expect(
      sql,
      contains('grant select on table public.v3_items to authenticated'),
    );
    expect(
      sql,
      contains(
          'grant execute on function public.fetch_v3_item_index() to authenticated'),
    );
  });

  test('does not rewrite Items or remove legacy source evidence', () {
    final sql = compact(readMigration()).toLowerCase();

    expect(sql, isNot(contains('update public.v3_items')));
    expect(sql, isNot(contains('delete from public.v3_items')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('drop column')));
    expect(sql, isNot(contains('identified_display_name = null')));
    expect(
        sql,
        contains(
            'no item rows or legacy identification source fields are changed'));
  });
}
