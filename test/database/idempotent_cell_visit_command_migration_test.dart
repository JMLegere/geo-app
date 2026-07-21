import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final migration = File(
    '${Directory.current.path}/supabase/migrations/'
    '083_idempotent_cell_visit_command.sql',
  );

  String readMigration() {
    expect(migration.existsSync(), isTrue);
    return migration.readAsStringSync();
  }

  test('is additive and preserves every existing Cell Visit', () {
    final sql = readMigration();

    expect(sql, contains('ADD COLUMN IF NOT EXISTS client_event_id TEXT'));
    expect(sql, contains('NOT VALID'));
    expect(sql, contains('client_event_id IS NULL'));
    expect(sql, isNot(contains('TRUNCATE TABLE')));
    expect(sql, isNot(contains('DELETE FROM public.v3_cell_visits')));
    expect(sql, isNot(contains('DROP TABLE public.v3_cell_visits')));
    expect(sql, contains('client reported'));
    expect(sql, contains('beta limitation'));
  });

  test('adds one partial unique durable identity per user client event', () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE UNIQUE INDEX IF NOT EXISTS '
        'idx_v3_cell_visits_user_client_event_id',
      ),
    );
    expect(sql, contains('(user_id, client_event_id)'));
    expect(sql, contains('WHERE client_event_id IS NOT NULL'));
  });

  test('defines a secured authenticated Cell Visit command', () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.record_v3_cell_visit(\n'
        '  p_cell_id TEXT,\n'
        '  p_client_event_id TEXT\n'
        ')\n'
        'RETURNS JSONB',
      ),
    );
    expect(sql, contains('SECURITY DEFINER'));
    expect(sql, contains('SET search_path = public'));
    expect(sql, contains('v_user_id UUID := auth.uid()'));
    expect(sql, contains('btrim(p_cell_id)'));
    expect(sql, contains('btrim(p_client_event_id)'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) '
        'FROM PUBLIC, anon',
      ),
    );
    expect(
      sql,
      contains(
        'GRANT EXECUTE ON FUNCTION public.record_v3_cell_visit(TEXT, TEXT) '
        'TO authenticated',
      ),
    );
  });

  test('server-stamps first visit and returns only the exact runtime JSON', () {
    final sql = readMigration();

    expect(sql, contains('v_visited_at TIMESTAMPTZ := now()'));
    expect(sql, contains('v_visited_at'));
    expect(sql, contains("'id', v_visit.id"));
    expect(sql, contains("'user_id', v_visit.user_id"));
    expect(sql, contains("'cell_id', v_visit.cell_id"));
    expect(sql, contains("'client_event_id', v_visit.client_event_id"));
    expect(sql, contains("'visited_at', v_visit.visited_at"));
  });

  test('keeps Cell Visit rows immutable and undeletable', () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'CREATE OR REPLACE FUNCTION public.v3_prevent_cell_visit_mutation()',
      ),
    );
    expect(sql, contains("TG_OP = 'DELETE'"));
    expect(sql, contains('Cell Visits cannot be deleted'));
    expect(sql, contains('NEW.id IS NOT DISTINCT FROM OLD.id'));
    expect(sql, contains('NEW.user_id IS NOT DISTINCT FROM OLD.user_id'));
    expect(sql, contains('NEW.cell_id IS NOT DISTINCT FROM OLD.cell_id'));
    expect(
      sql,
      contains(
        'NEW.client_event_id IS NOT DISTINCT FROM OLD.client_event_id',
      ),
    );
    expect(sql, contains('NEW.visited_at IS NOT DISTINCT FROM OLD.visited_at'));
    expect(sql, contains('CREATE TRIGGER v3_cell_visits_immutable'));
    expect(
      sql,
      contains(
        'REVOKE ALL ON FUNCTION public.v3_prevent_cell_visit_mutation() '
        'FROM PUBLIC, anon, authenticated',
      ),
    );
  });

  test('returns a canonical retry but rejects an event reused for another cell',
      () {
    final sql = readMigration();

    expect(sql, contains('ON CONFLICT (user_id, client_event_id)'));
    expect(sql, contains('DO NOTHING'));
    expect(sql, contains('FOR UPDATE'));
    expect(
        sql,
        contains(
            'p_client_event_id IS DISTINCT FROM btrim(p_client_event_id)'));
    expect(sql, contains('v_existing.cell_id IS DISTINCT FROM p_cell_id'));
    expect(sql, contains('cell_visit.client_event_id = p_client_event_id'));
    expect(
        sql, contains('Cell Visit client event belongs to a different cell'));
    expect(sql, isNot(contains('DO UPDATE')));
  });

  test('removes the sole direct authenticated insert policy but retains reads',
      () {
    final sql = readMigration();

    expect(
      sql,
      contains(
        'DROP POLICY IF EXISTS "v3_cell_visits_insert_own" '
        'ON public.v3_cell_visits',
      ),
    );
    expect(sql, isNot(contains('CREATE POLICY "v3_cell_visits_insert_own"')));
    expect(sql, isNot(contains('FOR INSERT TO authenticated')));
    expect(sql, isNot(contains('DROP POLICY "v3_cell_visits_select_own"')));
  });
}
