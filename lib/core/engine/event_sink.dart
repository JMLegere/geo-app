import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/engine/game_event.dart';
import 'package:earth_nova/core/services/device_fingerprint.dart';
import 'package:earth_nova/core/services/session_telemetry.dart' as telemetry;

typedef EventFlusher = Future<void> Function(List<Map<String, dynamic>> rows);
typedef UserIdResolver = String? Function();

const _storageKey = 'earthnova_events';

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

  Timer? _timer;
  bool _flushing = false;

  static const _flushInterval = Duration(seconds: 30);

  static EventSink? instance;

  static String _computeDeviceId() {
    try {
      return getDeviceFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  String get sessionId => _sessionId;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_flushInterval, (_) => flush());
    telemetry.writeTelemetry('earthnova_session_id', _sessionId);
    telemetry.writeTelemetry('earthnova_device_id', _deviceId);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  final List<String> _memoryBuffer = [];

  void add(GameEvent event) {
    final userId = _userIdResolver?.call();
    final row = event.toRow(
      sessionId: _sessionId,
      userId: userId,
      deviceId: _deviceId,
    );
    final encoded = jsonEncode(row);
    telemetry.appendTelemetryList(_storageKey, encoded);
    if (!kIsWeb) _memoryBuffer.add(encoded);
  }

  Future<void> flush() async {
    if (_flushing) return;

    final rawEntries = kIsWeb
        ? telemetry.drainTelemetryList(_storageKey)
        : List<String>.of(_memoryBuffer);
    if (!kIsWeb) _memoryBuffer.clear();
    if (rawEntries.isEmpty) return;

    _flushing = true;
    try {
      final rows = rawEntries
          .map((raw) => jsonDecode(raw) as Map<String, dynamic>)
          .toList();

      await _flusher(rows).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('[EventSink] flush timed out (${rows.length} events)');
          _restoreEvents(rawEntries);
        },
      );
    } catch (e) {
      debugPrint('[EventSink] flush failed: $e');
      _restoreEvents(rawEntries);
    } finally {
      _flushing = false;
    }
  }

  void _restoreEvents(List<String> rawEntries) {
    if (kIsWeb) {
      for (final entry in rawEntries) {
        telemetry.appendTelemetryList(_storageKey, entry);
      }
    } else {
      _memoryBuffer.addAll(rawEntries);
    }
  }

  static String get platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
}
