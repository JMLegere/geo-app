import 'package:uuid/uuid.dart';

class TraceContext {
  TraceContext({
    required this.traceId,
    required this.startTime,
  });

  final String traceId;
  final DateTime startTime;

  static TraceContext start() {
    return TraceContext(
      traceId: const Uuid().v4(),
      startTime: DateTime.now(),
    );
  }

  Duration get elapsed => DateTime.now().difference(startTime);
}
