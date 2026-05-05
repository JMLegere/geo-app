import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:earth_nova/core/observability/trace_context.dart';

abstract class TelemetryLoggerPort {
  void log(String event, String category, {Map<String, dynamic>? data});
  void logError(Object error, StackTrace stack,
      {String event = 'app.crash.unhandled'});
  void setUserId(String id);
  Future<void> flush();
}

abstract class TelemetryTracerPort {
  TelemetrySpan startSpan(
    String name, {
    TraceContext? parent,
    Map<String, dynamic>? attributes,
    String spanKind = 'internal',
  });

  void endSpan(
    TelemetrySpan span, {
    TelemetrySpanStatus statusCode = TelemetrySpanStatus.unset,
    String? statusMessage,
    Map<String, dynamic>? attributes,
  });
}

enum TelemetrySpanStatus { unset, ok, error }

enum TelemetryFlowPhase {
  started,
  waitingOn,
  dependencyRequested,
  dependencyReady,
  dependencyFailed,
  stateChanged,
  completed,
  failed,
  timedOut,
  cancelled,
}

extension TelemetryFlowPhaseWireName on TelemetryFlowPhase {
  String get wireName => switch (this) {
        TelemetryFlowPhase.started => 'started',
        TelemetryFlowPhase.waitingOn => 'waiting_on',
        TelemetryFlowPhase.dependencyRequested => 'dependency_requested',
        TelemetryFlowPhase.dependencyReady => 'dependency_ready',
        TelemetryFlowPhase.dependencyFailed => 'dependency_failed',
        TelemetryFlowPhase.stateChanged => 'state_changed',
        TelemetryFlowPhase.completed => 'completed',
        TelemetryFlowPhase.failed => 'failed',
        TelemetryFlowPhase.timedOut => 'timed_out',
        TelemetryFlowPhase.cancelled => 'cancelled',
      };
}

extension on TelemetrySpanStatus {
  String get wireName => switch (this) {
        TelemetrySpanStatus.unset => 'unset',
        TelemetrySpanStatus.ok => 'ok',
        TelemetrySpanStatus.error => 'error',
      };
}

class TelemetrySpan {
  const TelemetrySpan({
    required this.name,
    required this.context,
    required this.spanKind,
    required this.attributes,
  });

  final String name;
  final TraceContext context;
  final String spanKind;
  final Map<String, dynamic> attributes;

  String get traceId => context.traceId;
  String get spanId => context.spanId;
  String? get parentSpanId => context.parentSpanId;
  DateTime get startedAt => context.startTime;
}

/// Thin app-facing telemetry facade backed by an OTel-shaped ingest endpoint.
///
/// The call-site API intentionally remains ergonomic (`log`, `logError`,
/// `startSpan`, `endSpan`), while the buffered payload is split into OTel-like
/// log records and spans before it reaches Supabase.
class ObservabilityService implements TelemetryLoggerPort, TelemetryTracerPort {
  ObservabilityService({
    required this.sessionId,
    SupabaseClient? client,
    this.serviceName = 'earthnova-app',
    this.serviceVersion = const String.fromEnvironment(
      'APP_VERSION',
      defaultValue: 'dev',
    ),
    this.deploymentEnvironment = const String.fromEnvironment(
      'DEPLOYMENT_ENVIRONMENT',
      defaultValue: 'unknown',
    ),
    this.platform = kIsWeb ? 'web' : 'native',
  }) : _client = client;

  static const _ingestFunctionName = 'telemetry-ingest';

  final SupabaseClient? _client;
  final String sessionId;
  final String serviceName;
  final String serviceVersion;
  final String deploymentEnvironment;
  final String platform;

  String? _userId;
  final List<Map<String, dynamic>> _logBuffer = [];
  final List<Map<String, dynamic>> _spanBuffer = [];
  Timer? _flushTimer;

  @visibleForTesting
  List<Map<String, dynamic>> get pendingLogRecords =>
      List<Map<String, dynamic>>.unmodifiable(_logBuffer);

  @visibleForTesting
  List<Map<String, dynamic>> get pendingSpanRecords =>
      List<Map<String, dynamic>>.unmodifiable(_spanBuffer);

  /// Log a point-in-time OTel-shaped event.
  @override
  void log(String event, String category, {Map<String, dynamic>? data}) {
    final attributes = Map<String, dynamic>.from(data ?? const {});
    final traceId = _takeString(attributes, 'trace_id');
    final spanId = _takeString(attributes, 'span_id');
    final severityText = _takeString(attributes, 'severity_text') ??
        (category == 'error' ? 'ERROR' : 'INFO');
    final body = _takeString(attributes, 'body');

    _logBuffer.add({
      'session_id': sessionId,
      'user_id': _userId,
      'trace_id': _validTraceId(traceId),
      'span_id': _validSpanId(spanId),
      'trace_flags': '01',
      'severity_text': _normalizeSeverity(severityText),
      'category': category,
      'event_name': event,
      'body': body,
      'attributes': attributes,
      'occurred_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Log a lifecycle event using the debugging grammar:
  /// flow.started / waiting_on / dependency_* / state_changed / terminal.
  void logFlowEvent(
    String flow,
    TelemetryFlowPhase phase,
    String category, {
    TelemetrySpan? span,
    String? eventName,
    String? dependency,
    String? previousState,
    String? nextState,
    String? reason,
    Map<String, dynamic>? data,
  }) {
    final attributes = <String, dynamic>{
      ...?data,
      'flow': flow,
      'phase': phase.wireName,
      if (dependency != null) 'dependency': dependency,
      if (previousState != null) 'previous_state': previousState,
      if (nextState != null) 'next_state': nextState,
      if (reason != null) 'reason': reason,
      if (span != null) 'trace_id': span.traceId,
      if (span != null) 'span_id': span.spanId,
    };

    log(eventName ?? '$flow.${phase.wireName}', category, data: attributes);
  }

  /// Log an error with full raw detail for diagnosis.
  @override
  void logError(Object error, StackTrace stack,
      {String event = 'app.crash.unhandled'}) {
    final data = <String, dynamic>{
      'severity_text': 'ERROR',
      'error_type': error.runtimeType.toString(),
      'error_message': error.toString(),
      'stack_trace': stack.toString(),
    };
    if (error is AuthException) {
      data['supabase_code'] = error.message;
    } else if (error is PostgrestException) {
      data['supabase_code'] = error.code;
      data['supabase_message'] = error.message;
    }
    log(event, 'error', data: data);
  }

  /// Attach user ID to all subsequent records.
  @override
  void setUserId(String id) => _userId = id;

  @override
  TelemetrySpan startSpan(
    String name, {
    TraceContext? parent,
    Map<String, dynamic>? attributes,
    String spanKind = 'internal',
  }) {
    final context = parent == null ? TraceContext.start() : parent.child();
    final normalizedAttributes = <String, dynamic>{
      ...?attributes,
      'flow': attributes?['flow'] ?? name,
    };
    return TelemetrySpan(
      name: name,
      context: context,
      spanKind: _normalizeSpanKind(spanKind),
      attributes: normalizedAttributes,
    );
  }

  @override
  void endSpan(
    TelemetrySpan span, {
    TelemetrySpanStatus statusCode = TelemetrySpanStatus.unset,
    String? statusMessage,
    Map<String, dynamic>? attributes,
  }) {
    final mergedAttributes = <String, dynamic>{
      ...span.attributes,
      ...?attributes,
    };

    _spanBuffer.add({
      'trace_id': span.traceId,
      'span_id': span.spanId,
      'parent_span_id': span.parentSpanId,
      'span_name': span.name,
      'span_kind': span.spanKind,
      'started_at': span.startedAt.toUtc().toIso8601String(),
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      'status_code': statusCode.wireName,
      'status_message': statusMessage,
      'session_id': sessionId,
      'user_id': _userId,
      'attributes': mergedAttributes,
      'events': const <Map<String, dynamic>>[],
    });
  }

  /// Flush buffered records to the canonical telemetry ingest Edge Function.
  ///
  /// Never throws. Without a Supabase client, records are dropped after flush so
  /// tests/local mock mode cannot accumulate an unbounded buffer.
  @override
  Future<void> flush() async {
    if (_logBuffer.isEmpty && _spanBuffer.isEmpty) return;

    final logs = List<Map<String, dynamic>>.from(_logBuffer);
    final spans = List<Map<String, dynamic>>.from(_spanBuffer);

    final client = _client;
    if (client == null) {
      _logBuffer.clear();
      _spanBuffer.clear();
      return;
    }

    final envelope = {
      'resource': {
        'service_name': serviceName,
        'service_version': serviceVersion,
        'deployment_environment': deploymentEnvironment,
        'platform': platform,
      },
      'logs': logs,
      'spans': spans,
    };

    try {
      await client.functions.invoke(_ingestFunctionName, body: envelope);
      _logBuffer.clear();
      _spanBuffer.clear();
    } catch (e) {
      debugPrint('[Telemetry] flush failed: $e');
    }
  }

  /// Start periodic flush every 5 seconds.
  void startPeriodicFlush() {
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => flush());
  }

  void dispose() {
    _flushTimer?.cancel();
    flush();
  }

  String? _takeString(Map<String, dynamic> data, String key) {
    final value = data.remove(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  String? _validTraceId(String? value) {
    if (value == null) return null;
    return RegExp(r'^[0-9a-f]{32}$').hasMatch(value) ? value : null;
  }

  String? _validSpanId(String? value) {
    if (value == null) return null;
    return RegExp(r'^[0-9a-f]{16}$').hasMatch(value) ? value : null;
  }

  String _normalizeSeverity(String value) {
    final normalized = value.toUpperCase();
    const allowed = {'TRACE', 'DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'};
    return allowed.contains(normalized) ? normalized : 'INFO';
  }

  String _normalizeSpanKind(String value) {
    final normalized = value.toLowerCase();
    const allowed = {'internal', 'client', 'server', 'producer', 'consumer'};
    return allowed.contains(normalized) ? normalized : 'internal';
  }
}

/// SHA-256 hash a phone number for logging (never log raw phone numbers).
String hashPhone(String phone) {
  final bytes = utf8.encode(phone);
  return sha256.convert(bytes).toString();
}
