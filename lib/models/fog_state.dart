/// Represents the 5 discrete fog-of-war visibility states in the game.
///
/// States are **computed from player position and visit history** by
/// `FogStateResolver` — they are NOT stored per cell, and they are NOT
/// forward-only. A cell may freely move between states as the player moves
/// (e.g. current → explored when the player leaves, nearby → detected
/// when the player moves away from an adjacent cell).
///
/// The only persisted data is the set of cell IDs the player has physically
/// entered; all state values are derived from that set at resolution time.
enum FogState {
  /// Fog density: 1.0 (completely opaque)
  /// Player has never been near this cell.
  unknown(1.0),

  /// Fog density: 1.0 (fully opaque — same as unknown)
  /// Within detection zone or on exploration frontier, never visited.
  detected(1.0),

  /// Fog density: 0.95
  /// Adjacent to current cell — barely visible through thick fog.
  nearby(0.95),

  /// Fog density: 0.5
  /// Previously visited cell, not currently in view.
  explored(0.5),

  /// Fog density: 0.0 (completely transparent)
  /// Cell is fully revealed — player is here now.
  present(0.0);

  /// The fog density value for this state (0.0 = transparent, 1.0 = opaque)
  final double density;

  const FogState(this.density);

  /// Returns the string representation of this state (e.g., 'unknown')
  @override
  String toString() => name;

  /// Parses a string into a FogState enum value.
  ///
  /// Supports both new names and legacy names for backward compatibility
  /// with existing database records.
  static FogState fromString(String value) {
    // Support legacy names from existing DB records.
    switch (value) {
      case 'undetected':
        return FogState.unknown;
      case 'unexplored':
        return FogState.detected;
      case 'concealed':
        return FogState.nearby;
      case 'hidden':
        return FogState.explored;
      case 'observed':
        return FogState.present;
      default:
        return FogState.values.firstWhere(
          (state) => state.name == value,
          orElse: () => throw ArgumentError('Unknown FogState: $value'),
        );
    }
  }

  /// Returns true if this state is fully revealed (present).
  bool get isPresent => this == FogState.present;

  /// Returns true if this state implies the cell has been visited (explored or current).
  bool get isVisited => this == FogState.explored || this == FogState.present;
}
