import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Severity levels for debug log filtering.
///
/// Only lines at or above [DebugLogBuffer.minLevel] are stored in the
/// ring buffer. [classify] derives the level from line content so
/// existing `debugPrint` call-sites need no changes.
enum LogLevel {
  debug,
  info,
  warning,
  error;

  /// Classify a raw log line by scanning for known tags and keywords.
  ///
  /// Priority: error > warning > info > debug (first match wins).
  static LogLevel classify(String line) {
    // ── Error ──────────────────────────────────────────────────────────
    if (line.contains('[CRASH]')) return LogLevel.error;
    // "failed" / "error" in a tag context (not just the word "error" in a URL)
    final lower = line.toLowerCase();
    if (lower.contains('failed') || lower.contains('error:')) {
      return LogLevel.error;
    }
    if (lower.contains('corrupt')) return LogLevel.error;

    // ── Warning ────────────────────────────────────────────────────────
    if (lower.contains('timeout') ||
        lower.contains('timed out') ||
        lower.contains('rejected') ||
        lower.contains('retry') ||
        lower.contains('circuit breaker') ||
        lower.contains('rate limit') ||
        lower.contains('backing off') ||
        lower.contains('stale') ||
        lower.contains('skipping')) {
      return LogLevel.warning;
    }

    // ── Info (user-meaningful low-volume events) ───────────────────────
    if (line.contains('[AUTH]') ||
        line.contains('[Auth]') ||
        line.contains('[NAV]') ||
        line.contains('[ACTION]') ||
        line.contains('[CRASH-STACK]') ||
        line.contains('[RENDER-STALL]')) {
      return LogLevel.info;
    }

    // ── Debug (everything else: hydration, enrichment, per-cell ops) ──
    return LogLevel.debug;
  }
}

/// Ring buffer that captures debugPrint output for in-app viewing.
///
/// Singleton by necessity — debugPrint override requires a global target.
/// Capacity-limited to [maxLines] to avoid unbounded memory growth.
///
/// Set [minLevel] to control verbosity. Default is [LogLevel.warning] —
/// only warnings and errors are shown. Set to [LogLevel.debug] to see
/// everything (useful during development).
class DebugLogBuffer {
  DebugLogBuffer._();
  static final instance = DebugLogBuffer._();

  static const int maxLines = 2000;

  /// Minimum severity for a line to be stored in the ring buffer.
  /// Lines below this level are silently dropped from the viewer
  /// but crash/auth callbacks still fire regardless.
  LogLevel minLevel = LogLevel.warning;

  final _lines = Queue<String>();
  final _pending = <String>[];
  final _listeners = <VoidCallback>[];

  /// Called when a [CRASH] line is added. Wired by [LogFlushService] to
  /// trigger an immediate flush before the process dies.
  VoidCallback? onCrash;

  /// Called when an [AUTH] line is added. Wired by [LogFlushService] to
  /// capture sign-in attempts/failures before the 30s timer.
  VoidCallback? onAuthEvent;

  /// All buffered lines (oldest first).
  List<String> get lines => _lines.toList(growable: false);

  /// Number of buffered lines.
  int get length => _lines.length;

  /// Add a line to the buffer with an HH:mm:ss.SSS timestamp prefix.
  /// Evicts oldest if at capacity.
  ///
  /// Lines below [minLevel] are dropped from the ring buffer but
  /// crash/auth callbacks still fire for any line.
  void add(String line) {
    // Always check crash/auth callbacks regardless of level.
    if (line.contains('[CRASH]')) {
      onCrash?.call();
    } else if (line.contains('[AUTH]') ||
        line.contains('[Auth]') ||
        line.contains('[NAV]')) {
      onAuthEvent?.call();
    }

    // Always-pass tags bypass severity filtering so they appear in
    // the in-app debug viewer regardless of minLevel.
    final alwaysPass = line.contains('[API]') ||
        line.contains('[ART]') ||
        line.contains('[FRAME-PERF]') ||
        line.contains('[PERF]') ||
        line.contains('[Startup]') ||
        line.contains('[GameCoordinator]');

    // Filter by level — drop lines below minLevel.
    if (!alwaysPass) {
      final level = LogLevel.classify(line);
      if (level.index < minLevel.index) return;
    }

    final now = DateTime.now();
    final ts = '${_pad2(now.hour)}:${_pad2(now.minute)}:'
        '${_pad2(now.second)}.${_pad3(now.millisecond)}';
    final formatted = '[$ts] $line';
    _lines.addLast(formatted);
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
    if (_pending.length < 2000) {
      _pending.add(formatted);
    }
    _notifyListeners();
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');

  /// Drain pending lines for remote flush.
  ///
  /// Returns accumulated lines since last drain and clears the pending list.
  /// The ring buffer ([_lines]) is unaffected — in-app viewer keeps working.
  List<String> drainPending() {
    if (_pending.isEmpty) return const [];
    final drained = List<String>.of(_pending);
    _pending.clear();
    return drained;
  }

  /// Clear all buffered lines.
  void clear() {
    _lines.clear();
    _notifyListeners();
  }

  /// Guard against reentrant and concurrent-modification issues.
  ///
  /// A listener callback (e.g. the Riverpod bridge) can trigger widget
  /// rebuilds that call [addListener]/[removeListener] during iteration,
  /// or trigger another [debugPrint] → [add] cycle.  Copying the list and
  /// using a reentrant guard prevents both.
  bool _notifying = false;
  void _notifyListeners() {
    if (_notifying) return; // prevent reentrant calls
    _notifying = true;
    try {
      final snapshot = List<VoidCallback>.of(_listeners);
      for (final cb in snapshot) {
        cb();
      }
    } finally {
      _notifying = false;
    }
  }

  /// Register a change listener (for provider integration).
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Remove a change listener.
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}
