import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestObservabilityService extends ObservabilityService {
  _TestObservabilityService() : super(sessionId: 'test-session');

  final List<Map<String, dynamic>> events = [];

  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    events.add({
      'event': event,
      'category': category,
      'data': data ?? <String, dynamic>{},
    });
    super.log(event, category, data: data);
  }
}

class _TestObservableUseCase extends ObservableUseCase<String, String> {
  _TestObservableUseCase(this._obs, this._executeImpl);

  final ObservabilityService _obs;
  final Future<String> Function(String input, String traceId) _executeImpl;
  String? lastTraceId;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'test.operation';

  @override
  Future<String> execute(String input, String traceId) {
    lastTraceId = traceId;
    return _executeImpl(input, traceId);
  }
}

void main() {
  group('ObservableUseCase', () {
    test('logs started and completed with trace and timing data', () async {
      final obs = _TestObservabilityService();
      final useCase = _TestObservableUseCase(obs, (input, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return 'ok:$input';
      });

      final result = await useCase('alpha');

      expect(result, 'ok:alpha');
      expect(obs.events, hasLength(2));
      expect(obs.events[0]['event'], 'operation.started');
      expect(obs.events[1]['event'], 'operation.completed');

      final startedData = obs.events[0]['data'] as Map<String, dynamic>;
      final completedData = obs.events[1]['data'] as Map<String, dynamic>;
      final traceId = startedData['trace_id'] as String;

      expect(traceId, matches(RegExp(r'^[0-9a-f-]{36}$')));
      expect(completedData['trace_id'], traceId);
      expect(useCase.lastTraceId, traceId);
      expect(startedData['operation_name'], 'test.operation');
      expect(startedData['input_summary'], 'alpha');
      expect(completedData['output_summary'], 'ok:alpha');
      expect(completedData['duration_ms'], isA<int>());
      expect(completedData['duration_ms'] as int, greaterThanOrEqualTo(15));
    });

    test('logs started and failed with trace and timing data', () async {
      final obs = _TestObservabilityService();
      final useCase = _TestObservableUseCase(obs, (input, _) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw StateError('boom:$input');
      });

      await expectLater(useCase('beta'), throwsA(isA<StateError>()));
      expect(obs.events, hasLength(2));
      expect(obs.events[0]['event'], 'operation.started');
      expect(obs.events[1]['event'], 'operation.failed');

      final startedData = obs.events[0]['data'] as Map<String, dynamic>;
      final failedData = obs.events[1]['data'] as Map<String, dynamic>;
      final traceId = startedData['trace_id'] as String;

      expect(failedData['trace_id'], traceId);
      expect(useCase.lastTraceId, traceId);
      expect(failedData['duration_ms'], isA<int>());
      expect(failedData['duration_ms'] as int, greaterThanOrEqualTo(5));
      expect(failedData['error'], contains('boom:beta'));
    });
  });
}
