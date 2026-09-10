import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('web bootstrap retains low-level events for session diagnostics', () {
    final source = File('web/index.html').readAsStringSync();

    expect(
      source,
      contains("DIAGNOSTIC_OBS_KEY = 'earthnova_session_diagnostic_logs'"),
    );
    expect(source, contains('sessionStorage.setItem(DIAGNOSTIC_OBS_KEY'));
    expect(source, contains('while (diagnosticJson.length > MAX_BYTES'));
  });
}
