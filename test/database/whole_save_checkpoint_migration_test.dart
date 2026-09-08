import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String migration;
  setUpAll(() {
    migration = File('supabase/migrations/106_whole_save_checkpoints_and_shared_interactions.sql')
        .readAsStringSync();
  });

  test('atomically locks server head and compares accepted ancestry', () {
    expect(migration, contains('for update'));
    expect(migration, contains("'stale_ancestor'"));
    expect(migration, contains('unique (player_id, checkpoint_id)'));
  });

  test('ownership, complete shape and knowledge boundaries are validated', () {
    expect(migration, contains("p_save->>'playerId' <> actor::text"));
    expect(migration, contains("'incomplete_save_'"));
    expect(migration, contains("'hidden_information_forbidden'"));
  });

  test('shared interactions bind accepted revisions and deliver idempotently', () {
    expect(migration, contains('v3_shared_interaction_participants'));
    expect(migration, contains('references public.v3_player_save_revisions'));
    expect(migration, contains('unique (interaction_id, player_id)'));
    expect(migration, contains("'reconciliation_regression'"));
    expect(migration, contains('for update skip locked'));
    expect(migration, contains('complete_shared_interaction'));
    expect(migration, contains('delivery participant mismatch'));
  });
}
