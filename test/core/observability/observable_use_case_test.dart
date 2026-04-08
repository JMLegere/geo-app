import 'dart:io';

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
      expect(contents, contains('trace_id'));
      expect(contents, contains('duration_ms'));
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
