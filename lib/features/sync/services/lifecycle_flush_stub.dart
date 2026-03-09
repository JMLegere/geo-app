import 'lifecycle_flush.dart';

LifecycleFlush createLifecycleFlush() => _NoOpLifecycleFlush();

/// No-op implementation for native platforms.
///
/// On mobile, lifecycle flush is handled by [WidgetsBindingObserver] in the
/// widget tree (TabShell). This stub exists only to satisfy the conditional
/// import contract.
class _NoOpLifecycleFlush implements LifecycleFlush {
  @override
  Future<void> Function()? onFlush;

  @override
  void start() {}

  @override
  void dispose() {}
}
