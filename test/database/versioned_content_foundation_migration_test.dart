import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '076_versioned_content_foundation.sql',
  );

  test(
      'versioned content foundation defines the seven canonical base item categories',
      () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    final compactSql = sql.replaceAll(RegExp(r'\s+'), ' ');
    expect(sql, contains('create table if not exists v3_base_items'));
    expect(
      compactSql,
      contains(
        "category text not null check ( category in ( 'fauna', 'flora', "
        "'mineral', 'fossil', 'artifact', 'food', 'orb' ) )",
      ),
    );
  });

  test('base item versions keep an immutable revision identity', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(sql, contains('create table if not exists v3_base_item_versions'));
    expect(sql, contains('id uuid primary key default gen_random_uuid()'));
    expect(sql,
        contains('base_item_id text not null references v3_base_items(id)'));
    expect(sql, contains('revision integer not null check (revision > 0)'));
    expect(sql, contains('unique (base_item_id, revision)'));
    expect(sql, contains('unique (base_item_id, id)'));
    expect(sql, contains('authored_content jsonb not null default'));
  });

  test('publication points only to a version owned by the same base item', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(sql, contains('current_published_version_id uuid'));
    expect(sql, contains('foreign key (id, current_published_version_id)'));
    expect(sql, contains('references v3_base_item_versions(base_item_id, id)'));
    expect(
        sql,
        contains(
            'create or replace function public.publish_v3_base_item_version('));
    expect(sql, contains('base_item_id = p_base_item_id'));
    expect(sql, contains('id = p_version_id'));
    expect(sql, contains('for update'));
    expect(
      sql,
      contains(
        'revoke all on function public.publish_v3_base_item_version(text, uuid) from public',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.publish_v3_base_item_version(text, uuid) to service_role',
      ),
    );
    expect(sql, isNot(contains('auth.uid()')));
  });

  test('published authored content cannot be edited, reverted, or deleted', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(sql,
        contains('v3_base_item_versions_prevent_published_content_mutation'));
    expect(sql, contains('before update or delete on v3_base_item_versions'));
    expect(sql,
        contains('authored_content is distinct from old.authored_content'));
    expect(sql, contains('new.published_at is distinct from old.published_at'));
    expect(sql, contains("old.publication_status = 'retired'"));
    expect(sql, contains("new.publication_status <> 'retired'"));
    expect(
        sql,
        contains(
            "raise exception 'published base item versions are immutable'"));
  });

  test('stable base item identity and category cannot be reinterpreted', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(sql, contains('on update restrict'));
    expect(sql, contains('v3_base_items_prevent_identity_mutation'));
    expect(sql, contains('before update or delete on v3_base_items'));
    expect(sql, contains('new.id is distinct from old.id'));
    expect(sql, contains('new.category is distinct from old.category'));
    expect(
        sql,
        contains(
            "raise exception 'base item identity and category are immutable'"));
  });

  test(
      'authenticating players can read published content but cannot author it directly',
      () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(
        sql, contains('alter table v3_base_items enable row level security'));
    expect(
        sql,
        contains(
            'alter table v3_base_item_versions enable row level security'));
    expect(sql, contains('create policy "v3_base_items_authenticated_read"'));
    expect(sql,
        contains('create policy "v3_base_item_versions_authenticated_read"'));
    expect(sql, contains('to authenticated'));
  });

  test('foundation migration is additive and preserves legacy data', () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync().toLowerCase();
    expect(sql, isNot(contains('drop table')));
    expect(sql, isNot(contains('truncate')));
    expect(sql, isNot(contains('delete from')));
    expect(sql, isNot(contains('alter table v3_items drop')));
    expect(sql, contains('exact immutable base item version'));
  });
}
