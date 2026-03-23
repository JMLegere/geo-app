/// Represents the 5 discrete fog-of-war visibility states in the game.
///
/// States are **computed from player position and visit history** by
/// `FogStateResolver` — they are NOT stored per cell, and they are NOT
/// forward-only. A cell may freely move between states as the player moves
/// (e.g. Active → Visited when the player leaves, Nearby → Detected
/// when the player moves away from an adjacent cell).
///
/// The only persisted data is the set of cell IDs the player has physically
/// entered; all state values are derived from that set at resolution time.
enum FogState {
  /// Fog density: 1.0 (completely opaque)
  /// No knowledge of this cell — fully shrouded.
  unknown(1.0),

  /// Fog density: 1.0 (completely opaque, but cell borders are visible)
  /// Within awareness zone or on visited perimeter, never entered.
  detected(1.0),

  /// Fog density: 0.95
  /// Adjacent to player's current cell — barely visible through thick fog.
  nearby(0.95),

  /// Fog density: 0.5
  /// Previously entered cell, player has since left.
  visited(0.5),

  /// Fog density: 0.0 (completely transparent)
  /// Player is currently in this cell.
  active(0.0);

  /// The fog density value for this state (0.0 = transparent, 1.0 = opaque)
  final double density;

  const FogState(this.density);

  /// Returns the string representation of this state (e.g., 'unknown')
  @override
  String toString() => name;

  /// Parses a string into a FogState enum value.
  ///
  /// Supports both current names and legacy names (pre-rename) for backward
  /// compatibility with persisted data in SQLite and Supabase.
  static FogState fromString(String value) {
    // Legacy name mapping (persisted data may use old names).
    switch (value) {
      case 'undetected':
        return FogState.unknown;
      case 'unexplored':
        return FogState.detected;
      case 'concealed':
        return FogState.nearby;
      case 'hidden':
        return FogState.visited;
      case 'observed':
        return FogState.active;
    }
    return FogState.values.firstWhere(
      (state) => state.name == value,
      orElse: () => throw ArgumentError('Unknown FogState: $value'),
    );
  }

  /// Returns true if this state is fully revealed (player is here now).
  bool get isActive => this == FogState.active;

  /// Returns true if this state implies the cell has been entered
  /// (visited or active).
  bool get isEntered => this == FogState.visited || this == FogState.active;

  // ── Deprecated accessors (remove after all call sites migrated) ─────────

  /// Deprecated — use [isActive] instead.
  bool get isObserved => isActive;

  /// Deprecated — use [isEntered] instead.
  bool get isVisited => isEntered;
}
