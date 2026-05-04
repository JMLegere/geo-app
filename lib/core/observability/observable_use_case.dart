import 'package:earth_nova/core/observability/observability_service.dart';

abstract class ObservableUseCase<Input, Output> {
  const ObservableUseCase();

  ObservabilityService get obs;
  String get operationName;

  Future<Output> call(Input input) async {
    final span = obs.startSpan(
      operationName,
      attributes: {
        'operation': operationName,
        'input': summarizeInput(input),
      },
    );
    final trace = span.context;

    obs.log(
      'operation.started',
      'use_case',
      data: {
        'operation': operationName,
        'trace_id': trace.traceId,
        'span_id': trace.spanId,
        'input': summarizeInput(input),
      },
    );

    try {
      final output = await execute(input, trace.traceId);
      obs.log(
        'operation.completed',
        'use_case',
        data: {
          'operation': operationName,
          'trace_id': trace.traceId,
          'span_id': trace.spanId,
          'duration_ms': trace.elapsed.inMilliseconds,
          'output': summarizeOutput(output),
        },
      );
      obs.endSpan(
        span,
        statusCode: TelemetrySpanStatus.ok,
        attributes: {'output': summarizeOutput(output)},
      );
      return output;
    } catch (error) {
      obs.log(
        'operation.failed',
        'use_case',
        data: {
          'operation': operationName,
          'trace_id': trace.traceId,
          'span_id': trace.spanId,
          'duration_ms': trace.elapsed.inMilliseconds,
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString(),
        },
      );
      obs.endSpan(
        span,
        statusCode: TelemetrySpanStatus.error,
        statusMessage: error.toString(),
        attributes: {
          'error_type': error.runtimeType.toString(),
          'error_message': error.toString(),
        },
      );
      rethrow;
    }
  }

  Future<Output> execute(Input input, String traceId);

  Object? summarizeInput(Input input) => null;
  Object? summarizeOutput(Output output) => null;
}
