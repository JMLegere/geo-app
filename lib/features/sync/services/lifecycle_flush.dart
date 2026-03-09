import 'lifecycle_flush_stub.dart'
    if (dart.library.html) 'lifecycle_flush_web.dart';

/// Flushes the write queue when the app is about to be killed.
///
/// On web, listens for the `visibilitychange` event and calls [onFlush]
/// when the page becomes hidden (tab close, tab switch, browser minimize).
///
/// On native platforms, this is a no-op — [WidgetsBindingObserver] in the
/// widget layer handles [AppLifecycleState.paused] instead.
abstract class LifecycleFlush {
  /// Start listening for lifecycle events. Calls [onFlush] when the app
  /// is about to lose focus / be killed.
  void start();

  /// Stop listening and clean up.
  void dispose();

  /// Callback invoked when the platform signals the app is backgrounding.
  /// Set by the caller before calling [start].
  Future<void> Function()? onFlush;

  factory LifecycleFlush() => createLifecycleFlush();
}
