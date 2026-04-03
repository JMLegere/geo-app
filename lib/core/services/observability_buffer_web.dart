import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart';
import 'package:earth_nova/core/services/debug_log_buffer.dart';
import 'package:earth_nova/core/services/device_fingerprint.dart';
import 'package:earth_nova/core/services/log_flush_service.dart';
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

  /// Installs browser-level event listeners for web lifecycle and JS errors.
  ///
  /// - `pagehide`: drains log buffer and flushes before browser may kill the page.
  /// - `error`: captures uncaught JS errors as [JS-ERROR] lines.
  /// - `unhandledrejection`: captures unhandled Promise rejections as [JS-REJECTION] lines.
  static void installWebLifecycleHooks() {
    window.addEventListener(
      'pagehide',
      ((Event _) {
        LogFlushService.instance
            ?.addLines(DebugLogBuffer.instance.drainPending());
        LogFlushService.instance?.flush();
      }).toJS,
    );

    window.addEventListener(
      'error',
      ((ErrorEvent event) {
        final msg = event.message;
        final src = event.filename;
        final line = event.lineno;
        DebugLogBuffer.instance.add('[JS-ERROR] $msg ($src:$line)');
      }).toJS,
    );

    window.addEventListener(
      'unhandledrejection',
      ((PromiseRejectionEvent event) {
        DebugLogBuffer.instance.add('[JS-REJECTION] ${event.reason}');
      }).toJS,
    );
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
