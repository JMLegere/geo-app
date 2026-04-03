import 'dart:collection';

import 'package:earth_nova/engine/game_event.dart';

class ObservabilityBuffer {
  ObservabilityBuffer({
    required this.sessionId,
    this.deviceId,
    this.userId,
    this.maxEntries = 500,
  });

  final String sessionId;
  final String? deviceId;
  String? userId;
  final int maxEntries;

  final ListQueue<Map<String, dynamic>> _rows =
      ListQueue<Map<String, dynamic>>();

  void recordLine(String line) {
    _push({
      'session_id': sessionId,
      'user_id': userId,
      'device_id': deviceId,
      'lines': line,
      'category': null,
      'event': null,
      'data': null,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  void recordEvent(GameEvent event, {required String line}) {
    final row = event.toRow();
    row['lines'] = line;
    _push(row);
  }

  List<Map<String, dynamic>> drainRows() {
    final drained = _rows.toList(growable: false);
    _rows.clear();
    return drained;
  }

  void requeueRows(List<Map<String, dynamic>> rows) {
    for (final row in rows.reversed) {
      _rows.addFirst(row);
    }
    while (_rows.length > maxEntries) {
      _rows.removeFirst();
    }
  }

  void _push(Map<String, dynamic> row) {
    _rows.addLast(row);
    while (_rows.length > maxEntries) {
      _rows.removeFirst();
    }
  }
}

class ObservabilityController {
  ObservabilityController({
    required this.buffer,
    required this.uploader,
  });

  final ObservabilityBuffer buffer;
  final Future<void> Function(List<Map<String, dynamic>> rows) uploader;

  void recordLine(String line) => buffer.recordLine(line);

  void recordEvent(GameEvent event, {required String line}) {
    buffer.recordEvent(event, line: line);
  }

  Future<bool> flush() async {
    final rows = buffer.drainRows();
    if (rows.isEmpty) return false;
    try {
      await uploader(rows);
      return true;
    } catch (_) {
      buffer.requeueRows(rows);
      rethrow;
    }
  }
}
