import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:earth_nova/core/services/crash_log_persistence.dart';

/// Ring buffer that captures debugPrint output for in-app viewing.
///
/// Singleton by necessity — debugPrint override requires a global target.
/// Capacity-limited to [maxLines] to avoid unbounded memory growth.
class DebugLogBuffer {
  DebugLogBuffer._();
  static final instance = DebugLogBuffer._();

  static const int maxLines = 500;

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
  void add(String line) {
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

    // Trigger immediate flush when a crash line is detected so logs
    // reach Supabase before the process dies.
    if (line.contains('[CRASH]')) {
      // Synchronous localStorage write — survives page refresh even if
      // the async Supabase flush gets cancelled by the browser.
      CrashLogPersistence.persist(_pending);
      onCrash?.call();
    } else if (line.contains('[AUTH]') ||
        line.contains('[Auth]') ||
        line.contains('[NAV]')) {
      onAuthEvent?.call();
    }
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
