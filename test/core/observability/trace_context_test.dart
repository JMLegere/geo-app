import 'package:earth_nova/core/observability/trace_context.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TraceContext', () {
    test('start generates trace id and captures start time', () {
      final before = DateTime.now();
      final context = TraceContext.start();
      final after = DateTime.now();

      expect(context.traceId, isNotEmpty);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(context.traceId),
        isTrue,
      );
      expect(context.startTime.isBefore(before), isFalse);
      expect(context.startTime.isAfter(after), isFalse);
    });

    test('elapsed returns positive duration after some time', () async {
      final context = TraceContext.start();

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(context.elapsed,
          greaterThanOrEqualTo(const Duration(milliseconds: 10)));
    });
  });
}
