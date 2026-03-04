/// Represents the 5 discrete fog-of-war visibility states in the game.
///
/// States are **computed from player position and visit history** by
/// `FogStateResolver` — they are NOT stored per cell, and they are NOT
/// forward-only. A cell may freely move between states as the player moves
/// (e.g. Observed → Hidden when the player leaves, Concealed → Unexplored
/// when the player moves away from an adjacent cell).
///
/// The only persisted data is the set of cell IDs the player has physically
/// entered; all state values are derived from that set at resolution time.
enum FogState {
  /// Fog density: 1.0 (completely opaque)
  /// Player has never entered this cell.
  undetected(1.0),

  /// Fog density: 0.95
  /// Adjacent to observed cell — barely visible through thick fog.
  concealed(0.95),

  /// Fog density: 0.75
  /// Within detection radius or on exploration frontier, never visited.
  unexplored(0.75),

  /// Fog density: 0.5
  /// Previously visited cell, not currently in view.
  hidden(0.5),

  /// Fog density: 0.0 (completely transparent)
  /// Cell is fully revealed and observed.
  observed(0.0);

  /// The fog density value for this state (0.0 = transparent, 1.0 = opaque)
  final double density;

  const FogState(this.density);

  /// Returns the string representation of this state (e.g., 'undetected')
  @override
  String toString() => name;

  /// Parses a string into a FogState enum value.
  /// 
  /// Throws [ArgumentError] if the string doesn't match any state.
  static FogState fromString(String value) {
    return FogState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw ArgumentError('Unknown FogState: $value'),
    );
  }

  /// Returns true if this state is fully revealed (observed).
  bool get isObserved => this == FogState.observed;

  /// Returns true if this state implies the cell has been visited (hidden or observed).
  bool get isVisited => this == FogState.hidden || this == FogState.observed;
}
