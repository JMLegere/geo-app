import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// App-owned bridge for the real MapLibre GL JS style-load signal on web.
///
/// `maplibre_gl_web` can leave the Flutter `onStyleLoadedCallback` path too
/// brittle to be the only readiness signal in production-like web runs. The
/// patched bootstrap in `web/index.html` dispatches this browser event from the
/// underlying MapLibre JS `load` event so MapScreen can advance style
/// readiness even when the plugin callback does not fire.
class BaseMapStyleLoadedSignal {
  BaseMapStyleLoadedSignal({required void Function(String source) onLoaded}) {
    _listener = ((web.Event _) {
      onLoaded('maplibre_js_load');
    }).toJS;

    web.window.addEventListener(eventName, _listener);
  }

  static const eventName = 'earthnova.maplibre.load';

  web.EventListener? _listener;

  void dispose() {
    final listener = _listener;
    if (listener == null) return;
    web.window.removeEventListener(eventName, listener);
    _listener = null;
  }
}
