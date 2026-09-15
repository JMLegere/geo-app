class BaseMapSettledSignal {
  const BaseMapSettledSignal({required void Function(String source) onSettled});

  static const eventName = 'earthnova.maplibre.idle';

  void dispose() {}
}
