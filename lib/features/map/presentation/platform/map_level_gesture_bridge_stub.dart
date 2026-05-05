class MapLevelGestureBridge {
  const MapLevelGestureBridge({
    required void Function(String direction, String source) onPinch,
  });

  static const closeEventName = 'earthnova.map_level_pinch.close';
  static const spreadEventName = 'earthnova.map_level_pinch.spread';

  void dispose() {}
}
