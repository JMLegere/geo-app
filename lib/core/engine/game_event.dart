import 'package:meta/meta.dart';

@immutable
class GameEvent {
  final String category;
  final String event;
  final Map<String, dynamic> data;
  final DateTime timestamp;

  const GameEvent({
    required this.category,
    required this.event,
    this.data = const {},
    required this.timestamp,
  });

  factory GameEvent.state(String event,
          [Map<String, dynamic> data = const {}]) =>
      GameEvent(
          category: 'state',
          event: event,
          data: data,
          timestamp: DateTime.now());

  factory GameEvent.user(String event,
          [Map<String, dynamic> data = const {}]) =>
      GameEvent(
          category: 'user',
          event: event,
          data: data,
          timestamp: DateTime.now());

  factory GameEvent.system(String event,
          [Map<String, dynamic> data = const {}]) =>
      GameEvent(
          category: 'system',
          event: event,
          data: data,
          timestamp: DateTime.now());

  factory GameEvent.performance(String event,
          [Map<String, dynamic> data = const {}]) =>
      GameEvent(
          category: 'performance',
          event: event,
          data: data,
          timestamp: DateTime.now());

  Map<String, dynamic> toRow({
    required String sessionId,
    String? userId,
    required String deviceId,
  }) {
    return {
      'session_id': sessionId,
      'user_id': userId,
      'device_id': deviceId,
      'category': category,
      'event': event,
      'data': data,
      'created_at': timestamp.toUtc().toIso8601String(),
    };
  }

  @override
  String toString() => 'GameEvent($category/$event, ${data.length} fields)';
}
