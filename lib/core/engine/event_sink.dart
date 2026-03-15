import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/services/device_fingerprint.dart';

typedef EventFlusher = Future<void> Function(List<Map<String, dynamic>> rows);
typedef UserIdResolver = String? Function();

class EventSink {
  EventSink({
    required EventFlusher flusher,
    UserIdResolver? userIdResolver,
  })  : _flusher = flusher,
        _userIdResolver = userIdResolver;

  final EventFlusher _flusher;
  final UserIdResolver? _userIdResolver;
  final String _sessionId = const Uuid().v4();
  late final String _deviceId = _computeDeviceId();

  final List<GameEvent> _pending = [];
  Timer? _timer;
  bool _flushing = false;

  static const _flushInterval = Duration(seconds: 30);
  static const _maxBatchSize = 100;

  static String _computeDeviceId() {
    try {
      return getDeviceFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  /// Global reference for code outside Riverpod (e.g. frame timing in main.dart).
  /// Set by gameCoordinatorProvider when EventSink is created.
  static EventSink? instance;

  String get sessionId => _sessionId;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => flush());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void add(GameEvent event) {
    _pending.add(event);
    if (_pending.length >= _maxBatchSize) {
      flush();
    }
  }

  Future<void> flush() async {
    if (_flushing || _pending.isEmpty) return;
    _flushing = true;
    try {
      final batch = List<GameEvent>.of(_pending);
      _pending.clear();

      final userId = _userIdResolver?.call();
      final rows = batch
          .map((e) => e.toRow(
                sessionId: _sessionId,
                userId: userId,
                deviceId: _deviceId,
              ))
          .toList();

      await _flusher(rows);
    } catch (e) {
      debugPrint('[EventSink] flush failed (${_pending.length} pending): $e');
    } finally {
      _flushing = false;
    }
  }

  static String get platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
}
