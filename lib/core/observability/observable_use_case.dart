import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:uuid/uuid.dart';

abstract class ObservableUseCase<Input, Output> {
  ObservabilityService get obs;
  String get operationName;

  Future<Output> call(Input input) async {
    final traceId = const Uuid().v4();
    final timer = Stopwatch()..start();
    obs.log('operation.started', 'use_case', data: {
      'trace_id': traceId,
      'operation_name': operationName,
      'input_summary': _summarize(input),
    });

    try {
      final output = await execute(input, traceId);
      timer.stop();
      obs.log('operation.completed', 'use_case', data: {
        'trace_id': traceId,
        'operation_name': operationName,
        'duration_ms': timer.elapsedMilliseconds,
        'output_summary': _summarize(output),
      });
      return output;
    } catch (error) {
      timer.stop();
      obs.log('operation.failed', 'use_case', data: {
        'trace_id': traceId,
        'operation_name': operationName,
        'duration_ms': timer.elapsedMilliseconds,
        'error': error.toString(),
      });
      rethrow;
    }
  }

  String _summarize(Object? value) => value.toString();

  Future<Output> execute(Input input, String traceId);
}
