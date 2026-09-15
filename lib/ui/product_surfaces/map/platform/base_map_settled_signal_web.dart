import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// App-owned bridge for the real MapLibre GL JS idle signal on web.
///
/// The `maplibre_gl_web` 0.25.0 package wires native `onMapIdle` on mobile
/// through the platform interface, but its web controller does not forward the
/// underlying MapLibre GL JS `idle` event. `web/index.html` patches the
/// MapLibre constructor and dispatches this custom browser event when the JS map
/// is loaded and viewport tiles are loaded. MapScreen listens here so the
/// steady-state gate prefers real map idleness over the timer fallback.
class BaseMapSettledSignal {
  BaseMapSettledSignal({required void Function(String source) onSettled}) {
    _listener = ((web.Event _) {
      onSettled('maplibre_js_idle');
    }).toJS;

    web.window.addEventListener(eventName, _listener);
  }

  static const eventName = 'earthnova.maplibre.idle';

  web.EventListener? _listener;

  void dispose() {
    final listener = _listener;
    if (listener == null) return;
    web.window.removeEventListener(eventName, listener);
    _listener = null;
  }
}
