import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('telemetry ingest edge function is the canonical OTel endpoint', () {
    final function = File(
      '${Directory.current.path}/supabase/functions/telemetry-ingest/index.ts',
    );

    expect(function.existsSync(), isTrue);

    final source = function.readAsStringSync();
    expect(source, contains('telemetry_logs'));
    expect(source, contains('telemetry_spans'));
    expect(source, contains('logs'));
    expect(source, contains('spans'));
    expect(source, contains('resource'));
    expect(source, contains('trace_id'));
    expect(source, contains('span_id'));
    expect(source, isNot(contains('app_logs')));
  });

  test('web bootstrap posts JS diagnostics to telemetry-ingest', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('/functions/v1/telemetry-ingest'));
    expect(html, contains('logs:'));
    expect(html, contains('event_name'));
    expect(html, isNot(contains('/functions/v1/beacon-events')));
  });
  test('telemetry ingest disables gateway JWT for sendBeacon', () {
    final config = File('supabase/config.toml').readAsStringSync();

    expect(config, contains('[functions.telemetry-ingest]'));
    expect(config, contains('verify_jwt = false'));
  });
}
