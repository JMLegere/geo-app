import 'dart:async';
import 'dart:developer' as developer;
import 'dart:js_interop';

import 'package:web/web.dart';

import 'lifecycle_flush.dart';

LifecycleFlush createLifecycleFlush() => _WebLifecycleFlush();

/// Web implementation: listens for `visibilitychange` to flush the write
/// queue before the browser kills the page.
///
/// The `visibilitychange` event fires when:
/// - User switches tabs
/// - User minimizes the browser
/// - User closes the tab (last event before unload)
/// - Mobile browser backgrounds the PWA
///
/// This is more reliable than `beforeunload` (which Safari throttles) and
/// fires early enough for a network request to complete.
class _WebLifecycleFlush implements LifecycleFlush {
  EventListener? _listener;

  @override
  Future<void> Function()? onFlush;

  @override
  void start() {
    _listener = ((Event event) {
      if (document.hidden) {
        developer.log(
          'visibilitychange → hidden, flushing write queue',
          name: 'sync.LIFECYCLE',
        );
        // Fire-and-forget — we can't await in an event listener, but the
        // browser gives hidden pages a few seconds of execution time.
        onFlush?.call();
      }
    }).toJS;
    document.addEventListener('visibilitychange', _listener);
  }

  @override
  void dispose() {
    if (_listener != null) {
      document.removeEventListener('visibilitychange', _listener);
      _listener = null;
    }
  }
}
