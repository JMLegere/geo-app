import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('examined Item media falls back to its enriched species definition', () {
    final sql = File(
      'supabase/migrations/107_item_media_backfill_projection.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('CREATE OR REPLACE FUNCTION public.v3_safe_item_projection'),
    );
    expect(
      sql,
      matches(
        RegExp(r"COALESCE\(p_item\.icon_url,\s*\(SELECT species\.icon_url"),
      ),
    );
    expect(
      sql,
      matches(
        RegExp(r"COALESCE\(p_item\.art_url,\s*\(SELECT species\.art_url"),
      ),
    );
    expect(sql, contains('species.definition_id = p_item.definition_id'));
  });
}
