class MapLibrePlatformViewVisibilityBridge {
  bool? _lastVisible;

  static const eventName = 'earthnova.maplibre.visibility';
  static const showEventName = '$eventName.show';
  static const hideEventName = '$eventName.hide';

  void setVisible(bool visible) {
    if (_lastVisible == visible) return;
    _lastVisible = visible;
  }

  void dispose() {}
}
