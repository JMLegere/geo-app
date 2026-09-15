import 'package:web/web.dart' as web;

/// Controls the real MapLibre HTML platform view on Flutter Web.
///
/// Flutter widgets such as Offstage/Stack can stop painting Dart widgets, but
/// an HTML platform view may remain visually above Flutter content. MapRoot uses
/// this bridge to keep the WebGL map mounted while making the DOM layer hidden
/// and non-interactive whenever a hierarchy screen is active.
class MapLibrePlatformViewVisibilityBridge {
  bool? _lastVisible;

  static const eventName = 'earthnova.maplibre.visibility';
  static const showEventName = '$eventName.show';
  static const hideEventName = '$eventName.hide';

  void setVisible(bool visible) {
    if (_lastVisible == visible) return;
    _lastVisible = visible;
    web.window
        .dispatchEvent(web.Event(visible ? showEventName : hideEventName));
  }

  void dispose() {
    setVisible(true);
  }
}
