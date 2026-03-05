import 'map_visibility_stub.dart'
    if (dart.library.html) 'map_visibility_web.dart';

/// Controls the visibility of the MapLibre platform view container via CSS.
///
/// On web, Flutter's [AnimatedOpacity] does NOT hide platform views because
/// [HtmlElementView] renders in a separate DOM layer above the Canvas.
/// Instead, we inject a CSS rule that hides `.maplibregl-map` by default
/// and remove it once fog layers are initialized.
///
/// On native platforms, this is a no-op — the map is hidden/revealed via
/// the normal Flutter widget tree.
abstract class MapVisibility {
  /// Inject a `<style>` rule that hides the MapLibre container (opacity 0).
  /// Call in [initState] before the map widget builds.
  void hideMapContainer();

  /// Fade the MapLibre container in (opacity 0 → 1 with CSS transition).
  /// Call after fog layers are initialized and first fog data is applied.
  void revealMapContainer();

  /// Clean up any injected style elements.
  void dispose();

  factory MapVisibility() => createMapVisibility();
}
