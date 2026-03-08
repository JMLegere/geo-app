import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/restoration/models/restoration_state.dart';

/// Riverpod notifier managing per-cell habitat restoration levels.
///
/// Restoration increases as unique species are collected in a cell.
/// Each unique species adds 1/3 restoration (3 = fully restored, level 1.0).
/// Collecting the same species twice in the same cell is a no-op.
///
/// ## Restoration formula
///
/// Level is computed as `min(uniqueSpeciesCount, 3) / 3.0` to avoid
/// floating-point accumulation errors (exact 1.0 at 3 species).
class RestorationNotifier extends Notifier<RestorationState> {
  @override
  RestorationState build() {
    return const RestorationState();
  }

  /// Records that [speciesId] was collected in [cellId].
  ///
  /// Updates the restoration level and species-tracking for the cell.
  /// No-op if [speciesId] has already been collected in [cellId].
  void recordCollection(String cellId, String speciesId) {
    // Deep-copy species map so state remains immutable.
    final updatedSpecies = <String, Set<String>>{
      for (final entry in state.cellSpecies.entries)
        entry.key: Set<String>.from(entry.value),
    };

    final speciesSet = updatedSpecies.putIfAbsent(cellId, () => {});
    if (speciesSet.contains(speciesId)) return;

    speciesSet.add(speciesId);

    final updatedLevels = Map<String, double>.from(state.levels);
    updatedLevels[cellId] = (speciesSet.length / 3.0).clamp(0.0, 1.0);

    state = RestorationState(
      levels: updatedLevels,
      cellSpecies: updatedSpecies,
    );
  }

  /// Returns the restoration level for [cellId] (0.0–1.0).
  ///
  /// Returns 0.0 for cells with no collected species.
  double getLevel(String cellId) {
    return state.levels[cellId] ?? 0.0;
  }

  /// Returns true if [cellId] is fully restored (level >= 1.0).
  bool isRestored(String cellId) {
    return getLevel(cellId) >= 1.0;
  }
}

/// Provider managing per-cell habitat restoration state.
///
/// Read [restorationProvider] to access restoration levels.
/// Call [RestorationNotifier.recordCollection] when a species is collected.
final restorationProvider =
    NotifierProvider<RestorationNotifier, RestorationState>(
        () => RestorationNotifier());
