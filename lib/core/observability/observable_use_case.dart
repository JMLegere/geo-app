import 'dart:async';

import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';

abstract class ObservableUseCase<Input, Output> {
  const ObservableUseCase();

  ObservabilityService get obs;
  String get operationName;

  FutureOr<Output> execute(Input input, TraceContext context);

  FutureOr<Output> call(Input input) {
    final context = TraceContext.start();
    final stopwatch = Stopwatch()..start();

    obs.log(
      'operation.started',
      'use_case',
      data: {
        'operation': operationName,
        'trace_id': context.traceId,
        'input_summary': _summarize(input),
      },
    );

    try {
      final result = execute(input, context);

      if (result is Future<Output>) {
        return result.then((value) {
          obs.log(
            'operation.completed',
            'use_case',
            data: {
              'operation': operationName,
              'trace_id': context.traceId,
              'duration_ms': stopwatch.elapsedMilliseconds,
              'output_summary': _summarize(value),
            },
          );
          return value;
        }).catchError((Object error, StackTrace stack) {
          obs.log(
            'operation.failed',
            'use_case',
            data: {
              'operation': operationName,
              'trace_id': context.traceId,
              'duration_ms': stopwatch.elapsedMilliseconds,
              'error_type': error.runtimeType.toString(),
              'error_message': error.toString(),
            },
          );
          throw error;
        });
      }

      obs.log(
        'operation.completed',
        'use_case',
        data: {
          'operation': operationName,
          'trace_id': context.traceId,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'output_summary': _summarize(result),
        },
      );

      return result;
    } catch (error) {
      obs.log(
        'operation.failed',
        'use_case',
        data: {
          'operation': operationName,
          'trace_id': context.traceId,
          'duration_ms': stopwatch.elapsedMilliseconds,
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString(),
        },
      );
      rethrow;
    }
  }

  Map<String, Object?> _summarize(Object? value) {
    if (value == null) {
      return {'kind': 'null'};
    }

    if (value is String) {
      return {
        'kind': 'string',
        'length': value.length,
      };
    }

    if (value is Map) {
      return {
        'kind': 'map',
        'length': value.length,
      };
    }

    if (value is Iterable) {
      return {
        'kind': 'iterable',
        'length': value.length,
      };
    }

    if (value is num || value is bool) {
      return {
        'kind': 'primitive',
        'type': value.runtimeType.toString(),
      };
    }

    return {
      'kind': 'object',
      'type': value.runtimeType.toString(),
    };
  }
}
