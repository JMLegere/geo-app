import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '103_item_examination_base_identity_projection.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test('examined projection reads immutable Base Item Version identity', () {
    final sql = readMigration().toLowerCase();
    final examinedStart = sql.indexOf('when exists');
    final unexaminedStart = sql.indexOf('else', examinedStart);
    expect(examinedStart, greaterThanOrEqualTo(0));
    expect(unexaminedStart, greaterThan(examinedStart));

    final examined = sql.substring(examinedStart, unexaminedStart);
    expect(examined, contains('from public.v3_base_item_versions as version'));
    expect(examined, contains("'display_name', ("));
    expect(examined, contains('select version.display_name'));
    expect(examined, contains('select version.scientific_name'));
    expect(examined, contains('version.id = p_item.base_item_version_id'));
    expect(examined, contains('version.base_item_id = p_item.base_item_id'));
    expect(examined, contains("'examination_state', 'examined'"));
    expect(examined, contains("'identification_state', 'unidentified'"));
  });

  test('keeps unexamined identity concealed and Property Values untouched', () {
    final sql = readMigration().toLowerCase();
    final unexamined = sql.substring(sql.lastIndexOf('else'));

    expect(
      unexamined,
      contains("'display_name', 'unidentified ' || lower(p_item.category)"),
    );
    expect(unexamined, contains("'examination_state', 'unexamined'"));
    for (final forbidden in const <String>[
      'update public.v3_items',
      'insert into public.v3_items',
      'delete from public.v3_items',
      'v3_item_property_values',
      'identified_display_name',
      'identified_scientific_name',
    ]) {
      expect(sql, isNot(contains(forbidden)));
    }
    expect(
      sql,
      contains(
        'revoke all on function public.v3_safe_item_projection(public.v3_items)',
      ),
    );
  });
}
