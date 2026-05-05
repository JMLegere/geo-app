import 'dart:io';

import 'package:earth_nova/core/observability/browser_telemetry_session_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('browser telemetry session bridge', () {
    test('native stub is safe and returns no browser session', () {
      expect(readBrowserTelemetrySessionId(), isNull);
      expect(
        () => publishTelemetrySessionToBrowser('test-session'),
        returnsNormally,
      );
    });

    test('main reuses and publishes the browser telemetry session on web', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      final facadeSource = File(
        'lib/core/observability/browser_telemetry_session_bridge.dart',
      ).readAsStringSync();
      final webSource = File(
        'lib/core/observability/browser_telemetry_session_bridge_web.dart',
      ).readAsStringSync();

      expect(mainSource, contains('readBrowserTelemetrySessionId()'));
      expect(
          mainSource, contains('publishTelemetrySessionToBrowser(sessionId)'));
      expect(facadeSource, contains('dart.library.js_interop'));
      expect(webSource, contains('earthnova_app_session_id'));
      expect(webSource, contains('earthnovaSetAppSessionId'));
      expect(webSource, contains('sessionStorage'));
    });
  });
}
