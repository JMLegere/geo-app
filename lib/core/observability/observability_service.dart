import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Stateless observability service — batches events and flushes to Supabase.
///
/// Never throws. If the Supabase client is null, logs to debugPrint only.
class ObservabilityService {
  ObservabilityService({
    required this.sessionId,
    SupabaseClient? client,
  }) : _client = client;

  final SupabaseClient? _client;
  final String sessionId;
  String? _userId;
  final List<Map<String, dynamic>> _buffer = [];
  Timer? _flushTimer;

  /// Log a structured event.
  void log(String event, String category, {Map<String, dynamic>? data}) {
    _buffer.add({
      'session_id': sessionId,
      'user_id': _userId,
      'category': category,
      'event': event,
      'data': data ?? {},
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Log an error with full raw detail for diagnosis.
  void logError(Object error, StackTrace stack,
      {String event = 'app.crash.unhandled'}) {
    final data = <String, dynamic>{
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

  /// Attach user ID to all subsequent events.
  void setUserId(String id) => _userId = id;

  /// Flush buffer to Supabase. Fire-and-forget. Silent on failure.
  Future<void> flush() async {
    if (_buffer.isEmpty) return;
    final events = List<Map<String, dynamic>>.from(_buffer);
    _buffer.clear();
    if (_client == null) return;
    try {
      await _client!.from('app_logs').insert(events);
    } catch (e) {
      debugPrint('[Observability] flush failed: $e');
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
}

/// SHA-256 hash a phone number for logging (never log raw phone numbers).
String hashPhone(String phone) {
  final bytes = utf8.encode(phone);
  return sha256.convert(bytes).toString();
}
