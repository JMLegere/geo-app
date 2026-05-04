import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('OTel observability migration creates canonical telemetry tables', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/047_otel_observability.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('CREATE TABLE telemetry_logs'));
    expect(sql, contains('CREATE TABLE telemetry_spans'));
    expect(sql, contains('trace_id'));
    expect(sql, contains('span_id'));
    expect(sql, contains('parent_span_id'));
    expect(sql, contains('service_name'));
    expect(sql, contains('service_version'));
    expect(sql, contains('deployment_environment'));
    expect(sql, contains('attributes jsonb'));
    expect(sql, contains('duration_ms bigint GENERATED ALWAYS AS'));
  });

  test('OTel observability migration keeps terminal-queryable views', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/047_otel_observability.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('telemetry_session_timeline_v'));
    expect(sql, contains('telemetry_recent_errors_v'));
    expect(sql, contains('telemetry_startup_funnel_v'));
    expect(sql, contains('telemetry_map_readiness_v'));
  });

  test('OTel observability migration kills old app_logs surface', () {
    final migration = File(
      '${Directory.current.path}/supabase/migrations/047_otel_observability.sql',
    );

    expect(migration.existsSync(), isTrue);

    final sql = migration.readAsStringSync();
    expect(sql, contains('DROP TABLE IF EXISTS app_logs CASCADE'));
    expect(sql, contains('DROP TABLE IF EXISTS app_events CASCADE'));
    expect(sql, contains('purge_old_app_logs'));
  });
}
