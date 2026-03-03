/// Per-cell restoration state managed by the restoration Riverpod notifier.
///
/// Tracks how many unique species have been collected in each cell
/// and the computed restoration level (0.0–1.0) for each cell.
class RestorationState {
  /// Maps cellId → restoration level (0.0–1.0).
  ///
  /// Level is computed as `min(uniqueSpeciesCount, 3) / 3.0`,
  /// so 3 unique species in a cell yields exactly 1.0.
  final Map<String, double> levels;

  /// Maps cellId → set of species IDs collected in that cell.
  ///
  /// Used to prevent double-counting the same species in the same cell.
  final Map<String, Set<String>> cellSpecies;

  const RestorationState({
    this.levels = const {},
    this.cellSpecies = const {},
  });

  /// Returns a copy of this state with the given fields replaced.
  RestorationState copyWith({
    Map<String, double>? levels,
    Map<String, Set<String>>? cellSpecies,
  }) {
    return RestorationState(
      levels: levels ?? this.levels,
      cellSpecies: cellSpecies ?? this.cellSpecies,
    );
  }
}
