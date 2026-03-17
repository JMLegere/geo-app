/// Business logic for habitat restoration levels.
///
/// Tracks per-cell restoration state in memory and prevents double-counting
/// the same species in the same cell. This class is a pure, Riverpod-free
/// service and can be tested in isolation.
///
/// ## Restoration formula
///
/// Each unique species collected in a cell contributes 1/3 restoration.
/// Level is computed as `min(uniqueSpeciesCount, 3) / 3.0`, which gives
/// exactly 1.0 at 3 species with no floating-point accumulation error.
class RestorationService {
  final Map<String, double> _levels = {};
  final Map<String, Set<String>> _cellSpecies = {};

  /// Returns the restoration level for [cellId] (0.0–1.0).
  ///
  /// Returns 0.0 for cells with no collected species.
  double getRestorationLevel(String cellId) {
    return _levels[cellId] ?? 0.0;
  }

  /// Records that [speciesId] was collected in [cellId].
  ///
  /// Each unique species adds 1/3 restoration (3 species = fully restored).
  /// Collecting the same species again in the same cell is a no-op.
  void recordCollection(String cellId, String speciesId) {
    final species = _cellSpecies.putIfAbsent(cellId, () => {});
    if (species.contains(speciesId)) return;

    species.add(speciesId);
    _levels[cellId] = (species.length / 3.0).clamp(0.0, 1.0);
  }

  /// Returns true if [cellId] is fully restored (level >= 1.0).
  bool isFullyRestored(String cellId) {
    return getRestorationLevel(cellId) >= 1.0;
  }

  /// Returns an unmodifiable view of all cells with restoration level > 0.
  Map<String, double> getAllRestorationLevels() {
    return Map.unmodifiable(_levels);
  }

  /// Loads restoration levels from persistence.
  ///
  /// Replaces current in-memory levels with [levels]. Species-per-cell
  /// tracking is cleared — only the aggregate levels are restored.
  void loadState(Map<String, double> levels) {
    _levels
      ..clear()
      ..addAll(levels);
    _cellSpecies.clear();
  }
}
