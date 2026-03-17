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
  String? userId;

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

  Future<void> flush() async {
    if (_flushing || _buffer.isEmpty) return;
    _flushing = true;
    try {
      final batch = List<Map<String, dynamic>>.of(_buffer);
      _buffer.clear();
      await _flusher(batch).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[Observability] flush timed out (${batch.length} entries)');
        _buffer.insertAll(0, batch);
      });
    } catch (e) {
      debugPrint('[Observability] flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  List<Map<String, dynamic>> recover() => const [];
}
