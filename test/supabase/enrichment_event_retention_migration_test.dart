import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _migrationPath =
    'supabase/migrations/108_restore_enrichment_event_retention.sql';

String _migrationSql() {
  final migration = File('${Directory.current.path}/$_migrationPath');
  expect(
    migration.existsSync(),
    isTrue,
    reason: 'Restore 30-day diagnostic retention with forward migration 108.',
  );
  return migration.readAsStringSync();
}

String _normalizedSql(String sql) => sql
    .replaceAll(RegExp(r'--[^\n]*|/\*[\s\S]*?\*/'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .toLowerCase()
    .trim();

void main() {
  test(
    'forward migration deletes only diagnostics strictly older than 30 days',
    () {
      final sql = _normalizedSql(_migrationSql());
      expect(
        sql,
        matches(
          RegExp(
            r'create or replace function public\.cleanup_old_enrichment_events'
            r'\(\s*\) returns void\b',
          ),
        ),
      );
      expect(
        sql,
        matches(
          RegExp(
            r"delete from public\.enrichment_events where created_at\s*<\s*"
            r"now\(\s*\)\s*-\s*interval '30 days'",
          ),
        ),
      );
      expect(RegExp(r'\bdelete from\b').allMatches(sql), hasLength(1));
      expect(sql, isNot(matches(RegExp(r'\btruncate\b'))));
      expect(sql, isNot(matches(RegExp(r'\b(?:commit|rollback)\b'))));
      expect(
        sql,
        isNot(
          matches(
            RegExp(
              r'\b(?:create|alter|drop)\s+(?:table|extension|trigger|policy)\b'
              r'|\b(?:insert into|update)\b'
              r'|process[-_]enrichment[-_]queue|net\.http_post',
            ),
          ),
        ),
      );
    },
  );

  test(
    'cleanup uses invoker privileges, safe fixed search path and postgres owner',
    () {
      final sql = _normalizedSql(_migrationSql());
      expect(sql, contains('security invoker'));
      expect(sql, isNot(contains('security definer')));
      expect(
        sql,
        matches(
          RegExp(
            r'\bset search_path\s*(?:=|to)\s*'
            r"(?:''|'pg_catalog(?:,\s*pg_temp)?'|pg_catalog(?:,\s*pg_temp)?)"
            r'(?= (?:as|language|security|set)\b|;)',
          ),
        ),
      );
      expect(
        sql,
        matches(
          RegExp(
            r'alter function public\.cleanup_old_enrichment_events'
            r'\(\s*\) owner to postgres\s*;',
          ),
        ),
      );
    },
  );

  test('PUBLIC and client roles lose cleanup execution', () {
    final sql = _normalizedSql(_migrationSql());
    final revokedRoles = RegExp(
      r'\brevoke (?:all(?: privileges)?|execute) on function '
      r'public\.cleanup_old_enrichment_events\(\s*\) from ([^;]+);',
    ).allMatches(sql).map((match) => match.group(1)!).join(', ');
    for (final role in ['public', 'anon', 'authenticated']) {
      expect(revokedRoles, matches(RegExp('\\b$role\\b')));
    }
  });

  test('one named daily cron schedule calls qualified cleanup', () {
    final sql = _normalizedSql(_migrationSql());
    expect(RegExp(r'\bcron\.schedule\s*\(').allMatches(sql), hasLength(1));
    expect(
      sql,
      matches(
        RegExp(
          r"cron\.schedule\s*\(\s*'cleanup-enrichment-events'\s*,\s*"
          r"'0 3 \* \* \*'\s*,\s*"
          r"(?:\$\$|\$[a-z_][a-z0-9_]*\$|')\s*"
          r'select public\.cleanup_old_enrichment_events\(\s*\)\s*;\s*'
          r"(?:\$\$|\$[a-z_][a-z0-9_]*\$|')\s*\)",
        ),
      ),
    );
  });

  final container = Platform.environment['RETENTION_TEST_CONTAINER'];
  test(
    'native SQL repairs cron and privileges, preserves protected data and cutoff',
    () async {
      // Missing migration fails before any fixture helper can run.
      final sql = _migrationSql();
      expect(
        _normalizedSql(sql),
        isNot(matches(RegExp(r'\b(?:commit|rollback)\b'))),
      );
      final fixture = container!;
      expect(fixture, matches(RegExp(r'^[0-9a-f]{64}$')));
      final inspection = jsonDecode(
        await _docker([
          'inspect',
          '--format',
          r'''{"id":{{json .Id}},
"label":{{json (index .Config.Labels "earthnova.retention-fixture")}},
"network":{{json .HostConfig.NetworkMode}},
"running":{{json .State.Running}}}''',
          fixture,
        ]),
      );
      switch (inspection) {
        case {
              'id': String id,
              'label': '613',
              'network': 'none',
              'running': true,
            }
            when id == fixture:
          break;
        default:
          fail(
            'Refusing SQL: fixture must match full owned ID, label 613, '
            'network none and running state.',
          );
      }
      final psql = [
        'exec',
        '--interactive',
        '--user=postgres',
        fixture,
        'psql',
        '--no-psqlrc',
        '--no-password',
        '--host=/tmp',
        '--username=postgres',
        '--dbname=retention_613_test',
        '--set=ON_ERROR_STOP=1',
        '--quiet',
        '--tuples-only',
        '--no-align',
      ];
      expect(
        await _docker(
          psql,
          input: 'SELECT current_database(), current_user, session_user;\n',
        ),
        'retention_613_test|postgres|postgres',
        reason: 'Refusing SQL mutations outside owned fixture database/role.',
      );
      final output = await _docker(
        psql,
        input:
            '$_setupSql\n$sql\n$_assertMigrationSql\n'
            '$sql\n$_assertMigrationSql\n$_assertCleanupSql',
      );
      expect(output, contains('retention fixture rolled back'));
    },
    skip: container == null
        ? 'Set RETENTION_TEST_CONTAINER to owned isolated PostgreSQL fixture ID; '
              'native SQL behavior/security not verified without fixture.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<String> _docker(List<String> arguments, {String? input}) async {
  final process = await Process.start('docker', [
    '--context',
    'default',
    ...arguments,
  ], runInShell: false);
  // Drain both pipes immediately, before writing stdin or awaiting process exit.
  final stdout = process.stdout.transform(utf8.decoder).join();
  final stderr = process.stderr.transform(utf8.decoder).join();
  if (input != null) process.stdin.write(input);
  await process.stdin.close();
  final exitCode = await process.exitCode;
  final output = await stdout;
  final errors = await stderr;
  expect(exitCode, 0, reason: 'Fixture command failed:\n$output\n$errors');
  return output.trim();
}

const _setupSql = r'''
BEGIN;
DO $guard$
BEGIN
  IF current_database() <> 'retention_613_test'
     OR current_user <> 'postgres' OR session_user <> 'postgres' THEN
    RAISE EXCEPTION 'Refusing mutations outside retention_613_test as postgres';
  END IF;
  IF current_setting('cron.database_name', true)
       IS DISTINCT FROM 'retention_613_test'
     OR current_setting('cron.launch_active_jobs', true)
       IS DISTINCT FROM 'off' THEN
    RAISE EXCEPTION 'Fixture requires pg_cron on retention_613_test with jobs off';
  END IF;
END;
$guard$;
CREATE EXTENSION IF NOT EXISTS pg_cron;
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END;
$roles$;
CREATE ROLE retention_fixture_owner NOLOGIN;
CREATE TABLE public.enrichment_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  definition_id text,
  provider_name text,
  asset_type text,
  duration_ms integer,
  error_message text,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.enrichment_events ENABLE ROW LEVEL SECURITY;
INSERT INTO public.enrichment_events
  (id, event_type, definition_id, provider_name, asset_type,
   duration_ms, error_message, metadata, created_at)
VALUES
  ('00000000-0000-0000-0000-000000000001', 'old', 'protected-species',
   'fixture', 'icon', 1, 'old diagnostic', '{"fixture":1}',
   now() - interval '30 days' - interval '1 microsecond'),
  ('00000000-0000-0000-0000-000000000002', 'cutoff', 'protected-species',
   'fixture', 'icon', 2, NULL, '{"fixture":2}', now() - interval '30 days'),
  ('00000000-0000-0000-0000-000000000003', 'new', 'protected-species',
   'fixture', 'icon', 3, NULL, '{"fixture":3}', now());
CREATE TEMP TABLE retention_events_before AS
  SELECT * FROM public.enrichment_events;
CREATE TEMP TABLE enrichment_events
  (LIKE public.enrichment_events INCLUDING ALL);
INSERT INTO pg_temp.enrichment_events (event_type, created_at)
  VALUES ('shadow-protected', now() - interval '60 days');
CREATE TEMP TABLE retention_protected_before (relation_name text, rows jsonb);
DO $protected$
DECLARE
  relation_name text;
BEGIN
  FOREACH relation_name IN ARRAY ARRAY[
    'v3_profiles', 'v3_items', 'v3_cell_visits', 'v3_write_queue',
    'profiles', 'item_instances', 'cell_progress', 'collected_species',
    'species_enrichment', 'v3_base_item_versions',
    'v3_encounter_definition_versions'
  ] LOOP
    EXECUTE format('CREATE TABLE public.%I '
      '(id integer PRIMARY KEY, payload jsonb NOT NULL, '
      'created_at timestamptz NOT NULL)', relation_name);
    EXECUTE format('INSERT INTO public.%I VALUES '
      '(613, ''{"protected":true}''::jsonb, now() - interval ''60 days'')',
      relation_name);
    EXECUTE format('INSERT INTO retention_protected_before '
      'SELECT %L, jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.%I t',
      relation_name, relation_name);
  END LOOP;
END;
$protected$;
CREATE FUNCTION public.cleanup_old_enrichment_events() RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $unsafe$
BEGIN
  DELETE FROM public.enrichment_events;
END;
$unsafe$;
ALTER FUNCTION public.cleanup_old_enrichment_events()
  OWNER TO retention_fixture_owner;
GRANT EXECUTE ON FUNCTION public.cleanup_old_enrichment_events()
  TO PUBLIC, anon, authenticated;
SELECT cron.schedule('cleanup-enrichment-events', '17 9 * * *', 'SELECT 613;');
SELECT cron.schedule('process-enrichment-queue', '*/5 * * * *', 'SELECT 42;');
CREATE TEMP TABLE retention_jobs_before AS
  SELECT * FROM cron.job;
''';

const _assertMigrationSql = r'''
DO $migration$
DECLARE
  routine pg_proc%ROWTYPE;
  protected record;
  current_rows jsonb;
BEGIN
  IF (SELECT count(*) FROM cron.job
      WHERE jobname = 'cleanup-enrichment-events') <> 1
     OR NOT EXISTS (
       SELECT FROM cron.job j JOIN retention_jobs_before b USING (jobid)
       WHERE j.jobname = 'cleanup-enrichment-events'
         AND j.schedule = '0 3 * * *'
         AND regexp_replace(lower(btrim(j.command)), '\s+', ' ', 'g')
           = 'select public.cleanup_old_enrichment_events();'
         AND to_jsonb(j) - 'schedule' - 'command'
           = to_jsonb(b) - 'schedule' - 'command'
     ) THEN
    RAISE EXCEPTION 'Cleanup cron job must repair schedule/command with same id';
  END IF;
  IF (SELECT jsonb_agg(to_jsonb(j) ORDER BY jobid) FROM cron.job j
      WHERE jobname <> 'cleanup-enrichment-events') IS DISTINCT FROM
     (SELECT jsonb_agg(to_jsonb(b) ORDER BY jobid) FROM retention_jobs_before b
      WHERE jobname <> 'cleanup-enrichment-events') THEN
    RAISE EXCEPTION 'Unrelated worker cron job changed';
  END IF;
  SELECT * INTO STRICT routine FROM pg_proc
    WHERE oid = 'public.cleanup_old_enrichment_events()'::regprocedure;
  IF routine.prosecdef OR routine.proowner <> 'postgres'::regrole
     OR routine.prorettype <> 'pg_catalog.void'::regtype
     OR NOT EXISTS (
       SELECT FROM unnest(routine.proconfig) setting
       WHERE replace(setting, '"', '') IN (
         'search_path=', 'search_path=pg_catalog', 'search_path=pg_catalog, pg_temp'
       )
     ) THEN
    RAISE EXCEPTION 'Cleanup must be postgres-owned invoker with safe search_path';
  END IF;
  IF EXISTS (
       SELECT FROM aclexplode(coalesce(routine.proacl,
         acldefault('f', routine.proowner))) acl
       WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
     ) OR has_function_privilege('anon', routine.oid, 'EXECUTE')
       OR has_function_privilege('authenticated', routine.oid, 'EXECUTE')
       OR NOT has_function_privilege('postgres', routine.oid, 'EXECUTE') THEN
    RAISE EXCEPTION 'Only trusted role may execute cleanup';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_class
          WHERE oid = 'public.enrichment_events'::regclass) THEN
    RAISE EXCEPTION 'Diagnostic RLS was disabled';
  END IF;
  IF (SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.enrichment_events e)
     IS DISTINCT FROM
     (SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM retention_events_before e) THEN
    RAISE EXCEPTION 'Applying migration must not alter diagnostic rows';
  END IF;
  FOR protected IN SELECT * FROM retention_protected_before LOOP
    EXECUTE format('SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.%I t',
      protected.relation_name) INTO current_rows;
    IF current_rows IS DISTINCT FROM protected.rows THEN
      RAISE EXCEPTION 'Migration altered protected data: %', protected.relation_name;
    END IF;
  END LOOP;
END;
$migration$;
''';

const _assertCleanupSql = r'''
SET LOCAL ROLE anon;
DO $anon$
BEGIN
  PERFORM public.cleanup_old_enrichment_events();
  RAISE EXCEPTION 'anon executed cleanup';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END;
$anon$;
RESET ROLE;
SET LOCAL ROLE authenticated;
DO $authenticated$
BEGIN
  PERFORM public.cleanup_old_enrichment_events();
  RAISE EXCEPTION 'authenticated executed cleanup';
EXCEPTION WHEN insufficient_privilege THEN
  NULL;
END;
$authenticated$;
RESET ROLE;
SET LOCAL search_path = pg_temp;
SELECT public.cleanup_old_enrichment_events();
SELECT public.cleanup_old_enrichment_events();
DO $cleanup$
DECLARE
  protected record;
  current_rows jsonb;
BEGIN
  IF (SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM public.enrichment_events e)
     IS DISTINCT FROM
     (SELECT jsonb_agg(to_jsonb(e) ORDER BY id) FROM retention_events_before e
      WHERE event_type IN ('cutoff', 'new')) THEN
    RAISE EXCEPTION 'Cleanup must delete only old row, keeping cutoff/new unchanged';
  END IF;
  IF (SELECT count(*) FROM pg_temp.enrichment_events
      WHERE event_type = 'shadow-protected') <> 1 THEN
    RAISE EXCEPTION 'Cleanup touched caller search_path shadow table';
  END IF;
  FOR protected IN SELECT * FROM retention_protected_before LOOP
    EXECUTE format('SELECT jsonb_agg(to_jsonb(t) ORDER BY id) FROM public.%I t',
      protected.relation_name) INTO current_rows;
    IF current_rows IS DISTINCT FROM protected.rows THEN
      RAISE EXCEPTION 'Cleanup altered protected data: %', protected.relation_name;
    END IF;
  END LOOP;
END;
$cleanup$;
ROLLBACK;
DO $rollback$
DECLARE
  relation_name text;
BEGIN
  FOREACH relation_name IN ARRAY ARRAY[
    'enrichment_events', 'v3_profiles', 'v3_items', 'v3_cell_visits',
    'v3_write_queue', 'profiles', 'item_instances', 'cell_progress',
    'collected_species', 'species_enrichment', 'v3_base_item_versions',
    'v3_encounter_definition_versions'
  ] LOOP
    IF to_regclass(format('public.%I', relation_name)) IS NOT NULL THEN
      RAISE EXCEPTION 'Fixture table survived rollback: %', relation_name;
    END IF;
  END LOOP;
  IF to_regprocedure('public.cleanup_old_enrichment_events()') IS NOT NULL
     OR EXISTS (SELECT FROM pg_roles WHERE rolname = 'retention_fixture_owner') THEN
    RAISE EXCEPTION 'Fixture routine/owner survived rollback';
  END IF;
  IF to_regclass('cron.job') IS NOT NULL THEN
    IF EXISTS (SELECT FROM cron.job WHERE jobname IN
        ('cleanup-enrichment-events', 'process-enrichment-queue')) THEN
      RAISE EXCEPTION 'Fixture jobs survived rollback';
    END IF;
  END IF;
END;
$rollback$;
SELECT 'retention fixture rolled back';
''';
