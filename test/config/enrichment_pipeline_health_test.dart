import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pipeline health treats incomplete required artwork as unhealthy', () {
    final source = File(
      'supabase/functions/pipeline-health/index.ts',
    ).readAsStringSync();

    expect(source, contains('artwork_complete'));
    expect(source, contains('missing_required_artwork'));
    expect(source, contains('isUnhealthy'));
    expect(source, contains('status: isUnhealthy ? 503 : 200'));
  });

  test('enrichment LLM request has only one response format field', () {
    final source = File(
      'supabase/functions/process-enrichment-queue/index.ts',
    ).readAsStringSync();
    expect(
      RegExp(r'response_format: \{ type: "json_object" \}').allMatches(source),
      hasLength(1),
    );
  });
}
