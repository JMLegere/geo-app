import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Bridges thresholded pinches that start inside the MapLibre web platform view
/// back into Dart.
///
/// Flutter's `GestureDetector` can miss touches that originate on the HTML
/// platform view. The browser bootstrap emits these events after low-level
/// telemetry proves a thresholded close/spread pinch occurred inside MapLibre.
class MapLevelGestureBridge {
  MapLevelGestureBridge({
    required void Function(String direction, String source) onPinch,
  }) {
    _closeListener = ((web.Event _) {
      onPinch('close', 'maplibre_js_pinch_bridge');
    }).toJS;
    _spreadListener = ((web.Event _) {
      onPinch('spread', 'maplibre_js_pinch_bridge');
    }).toJS;

    web.window.addEventListener(closeEventName, _closeListener);
    web.window.addEventListener(spreadEventName, _spreadListener);
  }

  static const closeEventName = 'earthnova.map_level_pinch.close';
  static const spreadEventName = 'earthnova.map_level_pinch.spread';

  web.EventListener? _closeListener;
  web.EventListener? _spreadListener;

  void dispose() {
    final closeListener = _closeListener;
    if (closeListener != null) {
      web.window.removeEventListener(closeEventName, closeListener);
      _closeListener = null;
    }

    final spreadListener = _spreadListener;
    if (spreadListener != null) {
      web.window.removeEventListener(spreadEventName, spreadListener);
      _spreadListener = null;
    }
  }
}
