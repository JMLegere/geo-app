import 'dart:collection';

import 'package:flutter/foundation.dart';

/// Ring buffer that captures debugPrint output for in-app viewing.
///
/// Singleton by necessity — debugPrint override requires a global target.
/// Capacity-limited to [maxLines] to avoid unbounded memory growth.
class DebugLogBuffer {
  DebugLogBuffer._();
  static final instance = DebugLogBuffer._();

  static const int maxLines = 500;

  final _lines = Queue<String>();
  final _listeners = <VoidCallback>[];

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
    _lines.addLast('[$ts] $line');
    while (_lines.length > maxLines) {
      _lines.removeFirst();
    }
    for (final cb in _listeners) {
      cb();
    }
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');
  static String _pad3(int n) => n.toString().padLeft(3, '0');

  /// Clear all buffered lines.
  void clear() {
    _lines.clear();
    for (final cb in _listeners) {
      cb();
    }
  }

  /// Register a change listener (for provider integration).
  void addListener(VoidCallback listener) => _listeners.add(listener);

  /// Remove a change listener.
  void removeListener(VoidCallback listener) => _listeners.remove(listener);
}
