import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'package:earth_nova/core/services/debug_log_buffer.dart';

/// Periodically flushes [DebugLogBuffer] pending lines to the Supabase
/// `app_logs` table.
///
/// Fire-and-forget: flush failures are silently swallowed to avoid
/// feedback loops (logging a flush error would generate more log lines).
///
/// Lifecycle:
///   1. Construct with a [SupabaseClient].
///   2. Call [start] to begin the 30-second periodic flush.
///   3. Call [flush] on `AppLifecycleState.paused` for immediate drain.
///   4. Call [stop] on dispose (optional — Timer is lightweight).
class LogFlushService {
  LogFlushService(this._client);

  final SupabaseClient _client;
  final String _sessionId = const Uuid().v4();

  Timer? _timer;
  bool _flushing = false;

  /// Start the periodic 30-second flush timer.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => flush(),
    );
  }

  /// Stop the periodic flush timer.
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Drain pending lines and POST to Supabase.
  ///
  /// Safe to call from lifecycle observers. Returns immediately if a
  /// flush is already in progress or there are no pending lines.
  Future<void> flush() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final lines = DebugLogBuffer.instance.drainPending();
      if (lines.isEmpty) return;

      final userId = _client.auth.currentUser?.id;
      final data = <String, dynamic>{
        'session_id': _sessionId,
        'user_id': userId,
        'lines': lines.join('\n'),
        'app_version': _appVersion,
        'platform': _platform,
      };

      await _client.from('app_logs').insert(data);
    } catch (_) {
      // Silent failure — NEVER print/debugPrint here (infinite loop).
    } finally {
      _flushing = false;
    }
  }

  /// Platform string derived from Flutter's [defaultTargetPlatform].
  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name; // android, iOS, linux, macOS, windows
  }

  /// App version from compile-time dart-define, or 'unknown'.
  static const String _appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
}
