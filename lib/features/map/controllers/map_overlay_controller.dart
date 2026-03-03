/// Abstract interface for extensible map overlay layer controllers.
///
/// Concrete implementations (fog overlay, species markers, UI badges, etc.)
/// each get a unique [id], a [zOrder] for rendering priority, and a visibility
/// toggle. This interface is the Phase 1 contract; concrete widgets and
/// MapLibre wiring happen in Phase 2.
abstract class MapOverlayController {
  /// Unique identifier for this overlay layer.
  ///
  /// Used to look up and manage overlays in the layer stack.
  String get id;

  /// Rendering priority. Higher values render on top of lower values.
  ///
  /// Suggested z-order ranges:
  /// - 0–99: Base map overlays (fog, terrain)
  /// - 100–199: Game entity markers (species, cells)
  /// - 200–299: UI overlays (HUD, badges)
  int get zOrder;

  /// Whether this overlay is currently visible.
  bool get isVisible;

  /// Toggle visibility. Callers may suppress repaints while [isVisible] is false.
  set isVisible(bool value);

  /// Releases any resources held by this controller.
  ///
  /// Called when the overlay is removed from the layer stack or the map is
  /// disposed. Implementations must close streams, cancel subscriptions, etc.
  void dispose();
}
