import 'package:uuid/uuid.dart';

/// Minimal OpenTelemetry-shaped trace/span context.
///
/// OTel IDs are lowercase hex strings without UUID dashes:
/// - trace_id: 16 bytes / 32 hex chars
/// - span_id: 8 bytes / 16 hex chars
class TraceContext {
  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    required this.startTime,
  });

  factory TraceContext.start({DateTime? startTime}) => TraceContext(
        traceId: newTraceId(),
        spanId: newSpanId(),
        startTime: startTime ?? DateTime.now(),
      );

  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final DateTime startTime;

  Duration get elapsed => DateTime.now().difference(startTime);

  TraceContext child({DateTime? startTime}) => TraceContext(
        traceId: traceId,
        spanId: newSpanId(),
        parentSpanId: spanId,
        startTime: startTime ?? DateTime.now(),
      );

  static String newTraceId() => const Uuid().v4().replaceAll('-', '');

  static String newSpanId() =>
      const Uuid().v4().replaceAll('-', '').substring(0, 16);
}
