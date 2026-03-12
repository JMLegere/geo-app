import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/services/debug_log_buffer.dart';

/// Provides the current debug log lines as a reactive list.
///
/// Rebuilds whenever new lines are added to [DebugLogBuffer].
final debugLogProvider = Provider<List<String>>((ref) {
  final buffer = DebugLogBuffer.instance;

  void onChange() => ref.invalidateSelf();

  buffer.addListener(onChange);
  ref.onDispose(() => buffer.removeListener(onChange));

  return buffer.lines;
});
