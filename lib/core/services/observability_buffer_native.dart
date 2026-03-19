import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/services/device_fingerprint.dart';

typedef RemoteFlusher = Future<void> Function(List<Map<String, dynamic>> rows);

class ObservabilityBuffer {
  ObservabilityBuffer({required RemoteFlusher flusher}) : _flusher = flusher;

  static ObservabilityBuffer? instance;

  final RemoteFlusher _flusher;
  final String sessionId = const Uuid().v4();
  late final String deviceId = _safeDeviceId();
  String? _userId;

  static final _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String? get userId => _userId;
  set userId(String? value) {
    if (value != null && !_uuidPattern.hasMatch(value)) {
      debugPrint('[Observability] invalid userId ignored: $value');
      return;
    }
    _userId = value;
  }

  final List<Map<String, dynamic>> _buffer = [];
  Timer? _timer;
  bool _flushing = false;
  AppDatabase? _db;

  static String _safeDeviceId() {
    try {
      return getDeviceFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  void setDatabase(AppDatabase db) {
    _db = db;
  }

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void log(String message) => _add('log', 'debug_log', {'msg': message});
  void event(String name, [Map<String, dynamic> data = const {}]) =>
      _add('event', name, data);
  void js(String error) => _add('js', 'js_error', {'msg': error});
  void ui(String action) => _add('ui', 'ui_action', {'action': action});

  void _add(String category, String event, Map<String, dynamic> data) {
    final row = {
      'session_id': sessionId,
      'user_id': userId,
      'device_id': deviceId,
      'category': category,
      'event': event,
      'data': data,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    _buffer.add(row);

    // Persist locally for offline reconstruction
    _persistLocally(row);
  }

  void _persistLocally(Map<String, dynamic> row) {
    final db = _db;
    if (db == null) return;
    db.insertAppEvents([
      LocalAppEventsTableCompanion.insert(
        id: const Uuid().v4(),
        sessionId: row['session_id'] as String,
        userId: Value(row['user_id'] as String?),
        category: row['category'] as String,
        event: row['event'] as String,
        dataJson: Value(jsonEncode(row['data'])),
        createdAt: Value(DateTime.now().toUtc()),
      ),
    ]).catchError((Object e) {
      debugPrint('[Observability] local persist failed: $e');
    });
  }

  /// Max entries per flush. Larger batches are chunked to avoid timeouts.
  static const int _maxBatchSize = 50;

  /// Max consecutive failures before dropping the batch (prevents infinite retry).
  int _consecutiveFailures = 0;
  static const int _maxRetries = 3;

  Future<void> flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;
    try {
      // Chunk to avoid timeout on large batches.
      final batch = _buffer.length <= _maxBatchSize
          ? List<Map<String, dynamic>>.of(_buffer)
          : List<Map<String, dynamic>>.of(_buffer.take(_maxBatchSize).toList());
      _buffer.removeRange(0, batch.length);

      await _flusher(batch).timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException('flush timed out (${batch.length} entries)',
            const Duration(seconds: 5));
      });
      _consecutiveFailures = 0;
    } on TimeoutException {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _maxRetries) {
        debugPrint(
            '[Observability] flush failed $_consecutiveFailures times — dropping ${_buffer.length} entries');
        _buffer.clear();
        _consecutiveFailures = 0;
      } else {
        debugPrint(
            '[Observability] flush timed out (attempt $_consecutiveFailures/$_maxRetries)');
      }
    } catch (e) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _maxRetries) {
        debugPrint(
            '[Observability] flush failed $_consecutiveFailures times — dropping buffer');
        _buffer.clear();
        _consecutiveFailures = 0;
      } else {
        debugPrint(
            '[Observability] flush failed (attempt $_consecutiveFailures/$_maxRetries): $e');
      }
    } finally {
      _flushing = false;
    }
  }

  /// No-op — native events are persisted to SQLite via [_persistLocally] on
  /// every [_add] call.  Query [AppDatabase.getEventsBySession] for session
  /// replay.  Re-ingesting recovered events caused duplicate rows (41 %).
  List<Map<String, dynamic>> recover() => const [];
}
