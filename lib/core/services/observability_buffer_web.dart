import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:earth_nova/core/services/device_fingerprint.dart';
import 'package:earth_nova/core/services/startup_beacon.dart';

class ObservabilityBuffer {
  ObservabilityBuffer();

  static ObservabilityBuffer? instance;

  late final String sessionId = StartupBeacon.sessionId;
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

  static String _safeDeviceId() {
    try {
      return getDeviceFingerprint();
    } catch (_) {
      return 'unknown';
    }
  }

  /// Emit a structured event as a tagged debugPrint line.
  /// Flows through DebugLogBuffer → LogFlushService → app_logs.
  void event(String name, [Map<String, dynamic> data = const {}]) {
    if (data.isEmpty) {
      debugPrint('[EVENT] $name');
    } else {
      debugPrint('[EVENT] $name ${jsonEncode(data)}');
    }
  }
}
