import 'package:uuid/uuid.dart';

class TraceContext {
  TraceContext({
    required this.traceId,
    required this.startTime,
  });

  factory TraceContext.start() {
    return TraceContext(
      traceId: const Uuid().v4(),
      startTime: DateTime.now(),
    );
  }

  final String traceId;
  final DateTime startTime;

  Duration get elapsed => DateTime.now().difference(startTime);
}
