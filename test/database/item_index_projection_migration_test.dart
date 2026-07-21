import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '090_item_index_projection.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  String projectionBody(String sql) => RegExp(
        r'CREATE OR REPLACE FUNCTION public\.fetch_v3_item_index\(\)'
        r'[\s\S]*?\$\$;',
        caseSensitive: false,
      ).firstMatch(sql)!.group(0)!;

  List<String> entryFieldNames(String body) {
    final fields = RegExp(
      r'jsonb_agg\(\s*jsonb_build_object\(\s*([\s\S]*?)\s*\)\s*ORDER BY',
      caseSensitive: false,
    ).firstMatch(body)!.group(1)!;

    return RegExp(r"^\s*'([^']+)'\s*,", multiLine: true)
        .allMatches(fields)
        .map((match) => match.group(1)!)
        .toList();
  }

  test('projects only the authenticated owner\'s immutable Discovery Index',
      () {
    final body = projectionBody(readMigration());

    expect(body, contains('v_user_id UUID := auth.uid()'));
    expect(
        body,
        contains(
            "RAISE EXCEPTION 'Authentication is required to fetch the Item Index'"));
    expect(body, contains('WHERE discovery.user_id = v_user_id'));
    expect(body, contains('FROM public.v3_item_discoveries AS discovery'));
    expect(body, contains('JOIN public.v3_items AS first_item'));
    expect(
      compact(body),
      contains(
        'first_item.id = discovery.first_identified_item_id '
        'AND first_item.user_id = discovery.user_id '
        'AND first_item.base_item_id = discovery.base_item_id '
        'AND first_item.base_item_version_id = discovery.first_base_item_version_id',
      ),
    );
    expect(
      RegExp(r'FROM\s+public\.v3_item_discoveries\s+AS\s+discovery',
              caseSensitive: false)
          .allMatches(body)
          .length,
      1,
      reason:
          'The Discovery primary key is the one-entry-per-stable-Base-Item identity.',
    );
  });

  test(
      'retains the first exact Version and stable Base Item rather than a current publication',
      () {
    final body = projectionBody(readMigration());
    final normalized = compact(body);

    expect(
        normalized,
        contains(
            'JOIN public.v3_base_items AS base_item ON base_item.id = discovery.base_item_id'));
    expect(
      normalized,
      contains(
        'JOIN public.v3_base_item_versions AS base_item_version '
        'ON base_item_version.id = discovery.first_base_item_version_id '
        'AND base_item_version.base_item_id = discovery.base_item_id',
      ),
    );
    expect(body, contains("'base_item_version_id', base_item_version.id"));
    expect(body, contains("'base_item_revision', base_item_version.revision"));
    expect(body, isNot(contains('current_published_version_id')));
    expect(body, isNot(contains('publication_status')));
  });

  test(
      'returns a deterministic strict Index response with canonical exact-Version fields',
      () {
    final body = projectionBody(readMigration());
    final expectedFields = <String>[
      'base_item_id',
      'category',
      'first_identified_item_id',
      'base_item_version_id',
      'base_item_revision',
      'display_name',
      'scientific_name',
      'discovery_provenance',
      'discovered_at',
    ];

    expect(body, contains("'entries'"));
    expect(body, contains("'[]'::jsonb"));
    expect(entryFieldNames(body), orderedEquals(expectedFields));
    expect(body, contains("'category', base_item.category"));
    expect(
      compact(body).toLowerCase(),
      contains(
        "'display_name', coalesce( nullif( base_item_version.authored_content "
        "#>> '{legacy_item_snapshot,identified_display_name}', '' ), "
        'base_item_version.display_name )',
      ),
    );
    expect(
      compact(body).toLowerCase(),
      contains(
        "'scientific_name', coalesce( nullif( base_item_version.authored_content "
        "#>> '{legacy_item_snapshot,identified_scientific_name}', '' ), "
        'base_item_version.scientific_name )',
      ),
    );
    expect(
      compact(body),
      contains(
          'ORDER BY discovery.discovered_at DESC, discovery.base_item_id ASC'),
    );
    expect(body, isNot(contains('to_jsonb(')));
    expect(body, isNot(contains('jsonb_strip_nulls')));
  });

  test(
      'does not read Item-specific values, Pack multiplicity, or write durable state',
      () {
    final sql = readMigration().toLowerCase();

    expect(sql, isNot(contains('v3_item_property_values')));
    expect(sql, isNot(contains('first_item.identified_display_name')));
    expect(sql, isNot(contains('first_item.identified_scientific_name')));
    expect(sql, isNot(contains('count(')));
    expect(sql, isNot(contains('create table')));
    expect(sql, isNot(contains('alter table')));
    expect(sql, isNot(contains('create trigger')));
    expect(RegExp(r'\binsert\s+into\b').hasMatch(sql), isFalse);
    expect(RegExp(r'\bupdate\s+(?!or\s+delete\b)').hasMatch(sql), isFalse);
    expect(RegExp(r'\bdelete\s+from\b').hasMatch(sql), isFalse);
  });

  test('exposes only the no-input authenticated SECURITY DEFINER read RPC', () {
    final sql = readMigration();
    final normalized = compact(sql);

    expect(sql,
        contains('CREATE OR REPLACE FUNCTION public.fetch_v3_item_index()'));
    expect(sql, contains('RETURNS JSONB'));
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public'));
    expect(
      normalized,
      contains(
          'REVOKE ALL ON FUNCTION public.fetch_v3_item_index() FROM PUBLIC, anon'),
    );
    expect(
      normalized,
      contains(
          'GRANT EXECUTE ON FUNCTION public.fetch_v3_item_index() TO authenticated'),
    );
    expect(normalized, isNot(contains('TO PUBLIC')));
    expect(normalized, isNot(contains('TO anon')));
  });
}
