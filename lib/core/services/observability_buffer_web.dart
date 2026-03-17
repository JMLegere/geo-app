import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:web/web.dart' as web;

import 'package:earth_nova/core/services/device_fingerprint.dart';

typedef RemoteFlusher = Future<void> Function(List<Map<String, dynamic>> rows);

const _key = 'earthnova_obs';
const _maxBytes = 2 * 1024 * 1024;

class ObservabilityBuffer {
  ObservabilityBuffer({required RemoteFlusher flusher}) : _flusher = flusher;

  static ObservabilityBuffer? instance;

  final RemoteFlusher _flusher;
  final String sessionId = const Uuid().v4();
  late final String deviceId = _safeDeviceId();
  String? userId;

  Timer? _timer;
  bool _flushing = false;

  static String _safeDeviceId() {
    try {
      return getDeviceFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  /// No-op on web — local SQLite event persistence is native-only.
  void setDatabase(dynamic db) {}

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => flush());
    web.window.localStorage.setItem('earthnova_session_id', sessionId);
    web.window.localStorage.setItem('earthnova_device_id', deviceId);
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
    try {
      final row = jsonEncode({
        'session_id': sessionId,
        'user_id': userId,
        'device_id': deviceId,
        'category': category,
        'event': event,
        'data': data,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });

      final raw = web.window.localStorage.getItem(_key);
      final list = raw != null
          ? (jsonDecode(raw) as List<dynamic>).cast<String>()
          : <String>[];
      list.add(row);

      var serialized = jsonEncode(list);
      while (serialized.length > _maxBytes && list.length > 1) {
        list.removeAt(0);
        serialized = jsonEncode(list);
      }

      web.window.localStorage.setItem(_key, serialized);
    } catch (_) {}
  }

  int _flushedCount = 0;

  Future<void> flush() async {
    if (_flushing) return;

    List<String> entries;
    try {
      final raw = web.window.localStorage.getItem(_key);
      if (raw == null || raw.isEmpty) return;
      entries = (jsonDecode(raw) as List<dynamic>).cast<String>();
      // Only flush entries we haven't flushed yet.
      final unflushed = entries.skip(_flushedCount).toList();
      if (unflushed.isEmpty) return;
    } catch (_) {
      return;
    }

    _flushing = true;
    try {
      final unflushed = entries.skip(_flushedCount).toList();
      final rows =
          unflushed.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
      await _flusher(rows).timeout(const Duration(seconds: 5), onTimeout: () {
        debugPrint('[Observability] flush timed out (${rows.length} entries)');
      });
      // Mark these as flushed — but DON'T remove from localStorage.
      // The flight recorder keeps everything (2MB cap evicts oldest).
      _flushedCount = entries.length;
    } catch (e) {
      debugPrint('[Observability] flush failed: $e');
    } finally {
      _flushing = false;
    }
  }

  List<Map<String, dynamic>> recover() {
    try {
      final raw = web.window.localStorage.getItem(_key);
      if (raw == null || raw.isEmpty) return const [];
      final entries = (jsonDecode(raw) as List<dynamic>).cast<String>();
      web.window.localStorage.removeItem(_key);
      return entries.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    } catch (_) {
      return const [];
    }
  }
}
