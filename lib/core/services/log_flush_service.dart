import 'dart:async';

import 'package:flutter/foundation.dart';

/// Callback that ships a single row to the `app_logs` table.
typedef LogRowFlusher = Future<void> Function(Map<String, dynamic> row);

/// Debounced debug log flusher.
///
/// Accumulates lines from [DebugLogBuffer.drainPending] and ships them
/// to the Supabase `app_logs` table as a single text blob.
///
/// **Debounce behavior:** The first call to [addLines] arms a 5-second
/// timer.  Subsequent calls append without re-arming.  When the timer
/// fires, all accumulated lines flush in one INSERT.  If no lines arrive,
/// no timer runs and no network calls are made.
///
/// **Invariant:** If [_pending] is non-empty and [_disposed] is false,
/// then either [_flushTimer] is armed OR [_flushing] is true.
/// Violations mean lines could sit unflushed forever.
class LogFlushService {
  LogFlushService({
    required LogRowFlusher flusher,
    this.maxPending = 5000,
    Duration delay = const Duration(seconds: 5),
  })  : _flusher = flusher,
        _delay = delay;

  /// Global singleton — set by [gameCoordinatorProvider], read by
  /// [main.dart] drain timer and lifecycle observer.
  static LogFlushService? instance;

  final LogRowFlusher _flusher;
  final Duration _delay;

  /// Maximum lines to buffer before evicting oldest.
  final int maxPending;

  // ── Identity (set after construction by game_coordinator_provider) ───────
  String sessionId = '';
  String? userId;
  String deviceId = '';
  String? phoneNumber;

  // ── Internal state ──────────────────────────────────────────────────────
  final List<String> _pending = [];
  Timer? _flushTimer;
  bool _flushing = false;
  bool _disposed = false;
  int _consecutiveFailures = 0;

  static const int _maxRetries = 3;

  /// Platform string derived from Flutter's [defaultTargetPlatform].
  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// App version from compile-time dart-define.
  static const String _appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

  // ── Test-visible state ──────────────────────────────────────────────────

  /// Whether the core invariant holds: no unflushed lines without a
  /// timer or an in-flight flush (unless disposed).
  @visibleForTesting
  bool get invariantHolds =>
      _disposed || _pending.isEmpty || _flushing || _flushTimer != null;

  /// Number of lines waiting to be flushed.
  int get pendingCount => _pending.length;

  /// Whether the debounce timer is currently armed.
  @visibleForTesting
  bool get hasTimer => _flushTimer != null;

  // ── Public API ──────────────────────────────────────────────────────────

  /// Append drained debug log lines to the pending buffer.
  ///
  /// Arms the debounce timer on first call.  Subsequent calls before the
  /// timer fires just append.  Asserts in debug mode if called after
  /// [dispose] — in release mode it silently drops the lines.
  void addLines(List<String> lines) {
    assert(!_disposed, 'LogFlushService.addLines called after dispose');
    if (_disposed || lines.isEmpty) return;

    _pending.addAll(lines);
    if (_pending.length > maxPending) {
      _pending.removeRange(0, _pending.length - maxPending);
    }
    _ensureTimerIfNeeded();
  }

  /// Flush all pending lines immediately.
  ///
  /// Called by crash callbacks and lifecycle observers.  Safe to call
  /// at any time — no-ops if empty, disposed, or already flushing.
  Future<void> flush() async {
    if (_disposed || _flushing || _pending.isEmpty) return;

    // Guard: sessionId must be set before first flush. A blank session_id
    // would fail the app_logs uuid NOT NULL constraint. If not yet wired,
    // re-arm the timer so we try again next cycle.
    if (sessionId.isEmpty) {
      _ensureTimerIfNeeded();
      return;
    }

    _flushTimer?.cancel();
    _flushTimer = null;
    _flushing = true;

    final lines = List<String>.of(_pending);
    _pending.clear();

    try {
      await _flusher({
        'session_id': sessionId,
        'user_id': userId,
        'device_id': deviceId,
        'phone_number': phoneNumber,
        'lines': lines.join('\n'),
        'app_version': _appVersion,
        'platform': _platform,
      });
      _consecutiveFailures = 0;
    } catch (_) {
      _consecutiveFailures++;
      if (_consecutiveFailures >= _maxRetries) {
        debugPrint(
          '[LogFlush] $_consecutiveFailures consecutive failures — '
          'dropping ${lines.length} lines',
        );
        _consecutiveFailures = 0;
        // Lines are already cleared — drop them.
      } else {
        // Put lines back for retry. Cap to prevent unbounded growth if
        // new lines arrived via addLines() during the failed flush.
        _pending.insertAll(0, lines);
        if (_pending.length > maxPending) {
          _pending.removeRange(0, _pending.length - maxPending);
        }
      }
    } finally {
      _flushing = false;
      _ensureTimerIfNeeded();
    }
  }

  /// Cancel the debounce timer and mark as disposed.
  ///
  /// Any in-flight flush will complete but will not re-arm the timer.
  void dispose() {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /// Self-healing invariant enforcement.  Called after every state
  /// transition that could leave pending lines without a timer.
  void _ensureTimerIfNeeded() {
    if (_disposed) return;
    if (_pending.isNotEmpty && !_flushing && _flushTimer == null) {
      _flushTimer = Timer(_delay, _flushAndReset);
    }
  }

  /// Timer callback. Nulls the timer *before* calling flush() so that
  /// flush()'s own `_flushTimer?.cancel()` is a harmless no-op.
  void _flushAndReset() {
    _flushTimer = null;
    flush();
  }
}
