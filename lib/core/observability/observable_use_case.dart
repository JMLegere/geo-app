import 'package:earth_nova/core/observability/observability_service.dart';

abstract class ObservableUseCase<Input, Output> {
  const ObservableUseCase();

  ObservabilityService get obs;
  String get operationName;

  Future<Output> call(Input input) async {
    final span = obs.startSpan(
      operationName,
      attributes: {
        'flow': operationName,
        'operation': operationName,
        'input': summarizeInput(input),
      },
    );
    final trace = span.context;

    obs.logFlowEvent(
      operationName,
      TelemetryFlowPhase.started,
      'use_case',
      eventName: 'operation.started',
      span: span,
      data: {
        'operation': operationName,
        'input': summarizeInput(input),
      },
    );

    try {
      final output = await execute(input, trace.traceId);
      obs.logFlowEvent(
        operationName,
        TelemetryFlowPhase.completed,
        'use_case',
        eventName: 'operation.completed',
        span: span,
        data: {
          'operation': operationName,
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
      obs.logFlowEvent(
        operationName,
        TelemetryFlowPhase.failed,
        'use_case',
        eventName: 'operation.failed',
        span: span,
        data: {
          'operation': operationName,
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
