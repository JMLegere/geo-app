import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/core/observability/trace_context.dart';

abstract class ObservableUseCase<Input, Output> {
  const ObservableUseCase();

  ObservabilityService get obs;
  String get operationName;

  Future<Output> call(Input input) async {
    final trace = TraceContext.start();

    obs.log(
      'operation.started',
      'use_case',
      data: {
        'operation': operationName,
        'trace_id': trace.traceId,
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
          'duration_ms': trace.elapsed.inMilliseconds,
          'output': summarizeOutput(output),
        },
      );
      return output;
    } catch (error) {
      obs.log(
        'operation.failed',
        'use_case',
        data: {
          'operation': operationName,
          'trace_id': trace.traceId,
          'duration_ms': trace.elapsed.inMilliseconds,
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
