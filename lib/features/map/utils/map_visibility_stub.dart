import 'map_visibility.dart';

MapVisibility createMapVisibility() => _NoOpMapVisibility();

/// No-op implementation for native platforms where AnimatedOpacity works
/// correctly on platform views.
class _NoOpMapVisibility implements MapVisibility {
  @override
  void hideMapContainer() {}

  @override
  void revealMapContainer() {}

  @override
  void dispose() {}
}
