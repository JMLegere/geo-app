import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';

class ComputeEncounter {
  const ComputeEncounter();

  /// Computes an encounter based on cellId and seed.
  ///
  /// Uses SHA-256(seed + "_" + cellId) for deterministic species selection.
  ///
  /// Returns:
  /// - Species encounter on first visit
  /// - Critter encounter on revisit with loot (daily repopulated)
  /// - Null if no loot on revisit
  Encounter? call({
    required String cellId,
    required String seed,
    required bool isFirstVisit,
    bool hasLoot = false,
  }) {
    // If not first visit and no loot, no encounter
    if (!isFirstVisit && !hasLoot) {
      return null;
    }

    // Compute deterministic species ID from SHA-256(seed + "_" + cellId)
    final hashInput = '${seed}_$cellId';
    final hash = sha256.convert(utf8.encode(hashInput));

    // Use first 16 characters of hash as species ID
    // In a real implementation, this would map to actual species
    final speciesId = 'species_${hash.toString().substring(0, 16)}';

    // First visit = species encounter, revisit with loot = critter encounter
    final encounterType =
        isFirstVisit ? EncounterType.species : EncounterType.critter;

    return Encounter(
      type: encounterType,
      speciesId: speciesId,
      cellId: cellId,
      seed: seed,
    );
  }
}
