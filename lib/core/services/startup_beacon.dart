import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/config/supabase_config.dart';

/// Fire-and-forget startup telemetry.
///
/// Emits boot phase markers to the `app_logs` table so we have
/// observability on the startup path — including phases that run
/// BEFORE [ObservabilityBuffer] or [LogFlushService] are created.
///
/// **Two transport modes:**
/// - Pre-init: raw `http.post()` using compile-time dart-define credentials.
/// - Post-init: [SupabaseClient] INSERT (after [promote] is called).
///
/// Owns the session UUID used by all observability systems.
class StartupBeacon {
  StartupBeacon._();

  // ── Session identity (shared with ObservabilityBuffer + LogFlushService) ──

  static String? _sessionId;

  /// Lazily-generated session UUID. All observability systems read this.
  static String get sessionId => _sessionId ??= const Uuid().v4();

  // ── Transport ────────────────────────────────────────────────────────────

  static SupabaseClient? _client;

  /// Switch from raw HTTP to Supabase client. Call after
  /// [SupabaseBootstrap.initialize] succeeds.
  static void promote(SupabaseClient? client) => _client = client;

  // ── Test hooks ───────────────────────────────────────────────────────────

  /// When set, [emit] calls this instead of making real HTTP/Supabase calls.
  @visibleForTesting
  static void Function(Map<String, dynamic> row)? testFlusher;

  /// Reset all state for test isolation.
  @visibleForTesting
  static void resetForTest() {
    _client = null;
    _sessionId = null;
    testFlusher = null;
  }

  // ── Compile-time credentials (raw HTTP fallback) ─────────────────────────

  static const _url = SupabaseConfig.projectUrl;
  static const _anonKey = SupabaseConfig.anonKey;

  // ── Platform / version ───────────────────────────────────────────────────

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  static const String _appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  // ── Public API ───────────────────────────────────────────────────────────

  /// Fire-and-forget boot phase marker. Never throws, never blocks.
  static void emit(String phase, [Map<String, String>? extra]) {
    try {
      if (_url.isEmpty && testFlusher == null) return;

      final row = <String, dynamic>{
        'session_id': sessionId,
        'lines': _formatLine(phase, extra),
        'platform': _platform,
        'app_version': _appVersion,
      };

      if (testFlusher != null) {
        testFlusher!(row);
        return;
      }

      if (_client != null) {
        // Post-init: use Supabase client (goes through ObservableHttpClient
        // which already skips /rest/v1/app_logs to prevent circular logging).
        _client!.from('app_logs').insert(row);
      } else {
        // Pre-init: raw HTTP with anon key.
        http.post(
          Uri.parse('$_url/rest/v1/app_logs'),
          headers: {
            'apikey': _anonKey,
            'Authorization': 'Bearer $_anonKey',
            'Content-Type': 'application/json',
            'Prefer': 'return=minimal',
          },
          body: jsonEncode(row),
        );
      }
    } catch (_) {
      // Silent — startup must never fail because of telemetry.
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────

  static String _formatLine(String phase, Map<String, String>? extra) {
    final buf = StringBuffer('[BOOT] phase=$phase');
    extra?.forEach((k, v) => buf.write(' $k=$v'));
    return buf.toString();
  }
}
