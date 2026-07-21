import 'dart:io';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableUseCase enforcement', () {
    test('observable use case implementation logs expected operations', () {
      final file = File('lib/core/observability/observable_use_case.dart');

      expect(
        file.existsSync(),
        isTrue,
        reason:
            'Missing lib/core/observability/observable_use_case.dart. Add the base ObservableUseCase implementation first.',
      );

      final contents = file.readAsStringSync();

      expect(contents, contains('operation.started'));
      expect(contents, contains('operation.completed'));
      expect(contents, contains('operation.failed'));
      expect(contents, contains('span: span'));
      expect(contents, contains('duration_ms'));
      expect(contents, contains('logFlowEvent'));
      expect(contents, contains('TelemetryFlowPhase.started'));
      expect(contents, contains('TelemetryFlowPhase.completed'));
      expect(contents, contains('TelemetryFlowPhase.failed'));
    });

    test('child use case span retains the supplied root trace', () async {
      final service = ObservabilityService(sessionId: 'observable-use-case');
      final root = TraceContext(
        traceId: '0123456789abcdef0123456789abcdef',
        spanId: '0123456789abcdef',
        startTime: DateTime.utc(2026, 7, 20),
      );

      final output = await _EchoUseCase(service).call('value', parent: root);

      expect(output, 'value');
      expect(service.pendingSpanRecords, hasLength(1));
      expect(service.pendingSpanRecords.single['trace_id'], root.traceId);
      expect(service.pendingSpanRecords.single['parent_span_id'], root.spanId);
    });

    test('all domain use cases extend ObservableUseCase', () {
      final useCasesDir = Directory('lib/features');
      final violations = <String>[];

      for (final entity in useCasesDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (!entity.path.contains('/domain/use_cases/')) continue;

        final contents = entity.readAsStringSync();
        final hasAsyncCallMethod =
            RegExp(r'Future[^\n]*\s+call\s*\(').hasMatch(contents);
        final extendsObservableUseCase =
            RegExp(r'extends\s+ObservableUseCase<').hasMatch(contents);

        if (hasAsyncCallMethod && !extendsObservableUseCase) {
          violations.add(entity.path);
        }
      }

      violations.sort();

      expect(
        violations,
        isEmpty,
        reason:
            'These use case files define async call() without extending ObservableUseCase:\n'
            '${violations.join('\n')}\n\n'
            'All async domain use cases MUST extend ObservableUseCase<Input, Output> to ensure trace-aware observability.',
      );
    });
  });
}

final class _EchoUseCase extends ObservableUseCase<String, String> {
  const _EchoUseCase(this._obs);

  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'echo';

  @override
  Future<String> execute(String input, String traceId) async => input;
}
