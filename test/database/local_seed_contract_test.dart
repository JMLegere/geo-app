import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File('supabase/seed.sql').readAsStringSync();

  test('local seed is safe with no auth user and needs no templating', () {
    expect(sql, isNot(contains('{{TEST_USER_ID}}')));
    expect(sql, contains('FROM auth.users'));
    expect(sql, contains('IF test_user_id IS NULL THEN'));
    expect(sql, contains('RETURN;'));
    expect(sql, isNot(contains('INSERT INTO auth.users')));
  });

  test('local seed is replay-safe for one selected test user', () {
    expect(sql, isNot(contains('gen_random_uuid()')));
    expect(
      sql,
      contains(
          "md5(test_user_id::text || ':' || seed_item.base_item_id)::uuid"),
    );
    expect(sql, contains("'fauna:red_fox'"));
    expect(sql, contains('base_item_id'));
    expect(sql, contains('base_item_version_id'));
    expect(sql, contains('current_published_version_id'));
    expect(sql, contains('ON CONFLICT (id) DO NOTHING'));
    expect(
      RegExp(
        r'\b(delete\s+from|truncate\s+table|drop\s+(table|column))\b',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
    );
  });
}
