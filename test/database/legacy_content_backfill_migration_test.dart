import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '079_legacy_content_seed_and_item_binding.sql',
  );

  String compact(String value) => value.replaceAll(RegExp(r'\s+'), ' ');

  test('binds Items to nullable stable identities and exact immutable versions',
      () {
    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    final normalized = compact(sql).toLowerCase();

    expect(
        normalized,
        contains(
            'alter table v3_items add column if not exists base_item_id text'));
    expect(
      normalized,
      contains('add column if not exists base_item_version_id uuid'),
    );
    expect(
      RegExp(
        r'add column if not exists base_item_id text not null',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
      reason:
          'Existing rows need a compatibility backfill before a write-path cutover.',
    );
    expect(
      RegExp(
        r'add column if not exists base_item_version_id uuid not null',
        caseSensitive: false,
      ).hasMatch(sql),
      isFalse,
      reason:
          'Existing rows need a compatibility backfill before a write-path cutover.',
    );
    expect(sql, contains('v3_items_base_item_fk'));
    expect(sql, contains('FOREIGN KEY (base_item_id)'));
    expect(sql, contains('REFERENCES v3_base_items(id)'));
    expect(sql, contains('v3_items_base_item_version_owner_fk'));
    expect(sql, contains('FOREIGN KEY (base_item_id, base_item_version_id)'));
    expect(
      sql,
      contains('REFERENCES v3_base_item_versions(base_item_id, id)'),
    );
    expect(
      normalized,
      contains(
          '(base_item_id is null and base_item_version_id is null) or (base_item_id is not null and base_item_version_id is not null)'),
    );
  });

  test(
      'seeds all eight current catalog fauna identities with immutable snapshots',
      () {
    final sql = migration.readAsStringSync();

    const catalog = [
      (
        'amberwing_warbler',
        'Amberwing Warbler',
        'Setophaga aestiva',
        'Aves',
        '["forest", "wetland"]',
        '["North America"]'
      ),
      (
        'red_fox',
        'Red Fox',
        'Vulpes vulpes',
        'Mammalia',
        '["forest", "grassland", "urban"]',
        '["North America", "Europe", "Asia"]'
      ),
      (
        'monarch_butterfly',
        'Monarch Butterfly',
        'Danaus plexippus',
        'Insecta',
        '["grassland", "urban"]',
        '["North America"]'
      ),
      (
        'painted_turtle',
        'Painted Turtle',
        'Chrysemys picta',
        'Reptilia',
        '["freshwater", "wetland"]',
        '["North America"]'
      ),
      (
        'snowshoe_hare',
        'Snowshoe Hare',
        'Lepus americanus',
        'Mammalia',
        '["forest"]',
        '["North America"]'
      ),
      (
        'brook_trout',
        'Brook Trout',
        'Salvelinus fontinalis',
        'Actinopterygii',
        '["freshwater"]',
        '["North America"]'
      ),
      (
        'great_blue_heron',
        'Great Blue Heron',
        'Ardea herodias',
        'Aves',
        '["freshwater", "wetland", "coastal"]',
        '["North America"]'
      ),
      (
        'eastern_chipmunk',
        'Eastern Chipmunk',
        'Tamias striatus',
        'Mammalia',
        '["forest", "urban"]',
        '["North America"]'
      ),
    ];

    for (final entry in catalog) {
      expect(sql, contains('fauna:${entry.$1}'));
      expect(sql, contains(entry.$2));
      expect(sql, contains(entry.$3));
      expect(sql, contains(entry.$4));
      expect(sql, contains(entry.$5));
      expect(sql, contains(entry.$6));
    }

    expect(sql, contains("'fauna'"));
    expect(sql, contains("'published'"));
    expect(sql, contains('legacy_catalog_snapshot'));
    final canonicalSnapshot = RegExp(
      r"'legacy_catalog_snapshot',\s*jsonb_build_object\(([\s\S]*?)\)\s*\)\s*from",
      caseSensitive: false,
    ).firstMatch(sql);
    expect(canonicalSnapshot, isNotNull);
    expect(
      RegExp(r'rarity', caseSensitive: false).hasMatch(
        canonicalSnapshot!.group(1)!,
      ),
      isFalse,
      reason:
          'Canonical authored content must not turn legacy rarity into a mechanic.',
    );
    expect(sql, contains("'legacy_rarity', item.rarity"));
    expect(sql, contains('retained solely as evidence'));
  });

  test(
      'backfills every existing Item with deterministic compatibility snapshots',
      () {
    final sql = migration.readAsStringSync();
    final normalized = compact(sql).toLowerCase();

    expect(
        sql,
        contains(
            r"'^species\.(amberwing_warbler|red_fox|monarch_butterfly|painted_turtle|snowshoe_hare|brook_trout|great_blue_heron|eastern_chipmunk)\.[0-9a-f]{8}$'"));
    expect(sql, contains('legacy-item:'));
    expect(sql, contains('md5('));
    expect(sql, contains('legacy_item_snapshot'));
    expect(sql, contains('ON CONFLICT (id) DO NOTHING'));
    expect(sql, contains('ON CONFLICT (base_item_id, revision) DO NOTHING'));
    expect(
      normalized,
      contains("base_item.id like 'legacy-item:%'"),
    );
    expect(
      normalized,
      contains("and version.publication_status in ('published', 'retired')"),
    );
    expect(
      normalized,
      contains(
        "order by version.base_item_id, version.revision desc, case version.publication_status when 'published' then 0 else 1 end, version.id desc",
      ),
    );
    expect(
      normalized,
      contains('and base_item.current_published_version_id is null'),
    );
    expect(normalized, contains('update v3_items'));
    expect(normalized, contains('set base_item_id ='));
    expect(normalized, contains('base_item_version_id ='));
    final itemBindingUpdate = RegExp(
      r'update\s+v3_items\s+as\s+item\s+set\s+([\s\S]*?)\s+from\s+item_snapshots',
      caseSensitive: false,
    ).firstMatch(sql);
    expect(itemBindingUpdate, isNotNull);
    expect(
      RegExp(
        r'\b(?:id|user_id|definition_id|display_name|scientific_name|category|rarity|icon_url|art_url|acquired_at|acquired_in_cell_id|status|created_at|identification_state)\s*=',
        caseSensitive: false,
      ).hasMatch(itemBindingUpdate!.group(1)!),
      isFalse,
      reason:
          'The migration may bind the new FK columns only; legacy payload and identity stay intact.',
    );
    expect(
      normalized,
      contains('where base_item_id is null or base_item_version_id is null'),
    );
    expect(sql, contains('Legacy Item backfill left % unbound Item rows'));
  });

  test('is additive and leaves Cell Visit history untouched', () {
    final sql = migration.readAsStringSync();

    expect(RegExp(r'\bDROP\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(
        RegExp(r'\bTRUNCATE\b', caseSensitive: false).hasMatch(sql), isFalse);
    expect(RegExp(r'\bDELETE\s+FROM\b', caseSensitive: false).hasMatch(sql),
        isFalse);
    expect(
        RegExp(r'v3_cell_visits', caseSensitive: false).hasMatch(sql), isFalse);
  });
}
