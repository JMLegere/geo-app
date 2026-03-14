import 'package:web/web.dart' as web;

/// Web crash log persistence using localStorage.
///
/// Synchronously writes crash context to localStorage when a [CRASH] line
/// is detected. This survives page refresh even if the async Supabase
/// flush gets cancelled by the browser killing the page.
///
/// On next app load, [LogFlushService] should call [recover] and include
/// the recovered lines in its first flush, then [clear].
class CrashLogPersistence {
  CrashLogPersistence._();

  static const _key = 'earthnova_crash_log';

  /// Synchronously write crash context to localStorage.
  /// Takes the current pending buffer (most recent lines).
  static void persist(List<String> lines) {
    try {
      // Take last 50 lines — enough context without hitting storage limits.
      final tail = lines.length > 50 ? lines.sublist(lines.length - 50) : lines;
      web.window.localStorage.setItem(_key, tail.join('\n'));
    } catch (_) {
      // localStorage might be full or disabled — swallow silently.
    }
  }

  /// Recover crash context from a previous session, or null if none.
  static List<String>? recover() {
    try {
      final stored = web.window.localStorage.getItem(_key);
      if (stored == null || stored.isEmpty) return null;
      return stored.split('\n');
    } catch (_) {
      return null;
    }
  }

  /// Clear persisted crash context after successful flush.
  static void clear() {
    try {
      web.window.localStorage.removeItem(_key);
    } catch (_) {
      // Swallow.
    }
  }
}
