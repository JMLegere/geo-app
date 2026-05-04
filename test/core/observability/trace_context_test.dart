import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TraceContext', () {
    test('start generates OTel trace/span ids and captures start time', () {
      final before = DateTime.now();
      final context = TraceContext.start();
      final after = DateTime.now();

      expect(context.traceId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(context.spanId, matches(RegExp(r'^[0-9a-f]{16}$')));
      expect(context.parentSpanId, isNull);
      expect(context.startTime.isBefore(before), isFalse);
      expect(context.startTime.isAfter(after), isFalse);
    });

    test('child keeps trace id and links parent span', () {
      final parent = TraceContext.start();
      final child = parent.child();

      expect(child.traceId, parent.traceId);
      expect(child.parentSpanId, parent.spanId);
      expect(child.spanId, isNot(parent.spanId));
    });

    test('elapsed returns positive duration after some time', () async {
      final context = TraceContext.start();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(context.elapsed,
          greaterThanOrEqualTo(const Duration(milliseconds: 10)));
    });
  });
}
