class BaseMapStyleLoadedSignal {
  const BaseMapStyleLoadedSignal({required void Function(String source) onLoaded});

  static const eventName = 'earthnova.maplibre.load';

  void dispose() {}
}
