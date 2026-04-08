import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/encounter.dart';

typedef ComputeEncounterInput = ({
  String cellId,
  String seed,
  bool isFirstVisit,
  bool hasLoot,
});

class ComputeEncounter
    extends ObservableUseCase<ComputeEncounterInput, Encounter?> {
  ComputeEncounter(this._obs);

  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'compute_encounter';

  /// Computes an encounter based on cellId and seed.
  ///
  /// Uses SHA-256(seed + "_" + cellId) for deterministic species selection.
  ///
  /// Returns:
  /// - Species encounter on first visit
  /// - Critter encounter on revisit with loot (daily repopulated)
  /// - Null if no loot on revisit
  @override
  Future<Encounter?> execute(
      ComputeEncounterInput input, String traceId) async {
    // If not first visit and no loot, no encounter
    if (!input.isFirstVisit && !input.hasLoot) {
      return null;
    }

    // Compute deterministic species ID from SHA-256(seed + "_" + cellId)
    final hashInput = '${input.seed}_${input.cellId}';
    final hash = sha256.convert(utf8.encode(hashInput));

    // Use first 16 characters of hash as species ID
    // In a real implementation, this would map to actual species
    final speciesId = 'species_${hash.toString().substring(0, 16)}';

    // First visit = species encounter, revisit with loot = critter encounter
    final encounterType =
        input.isFirstVisit ? EncounterType.species : EncounterType.critter;

    return Encounter(
      type: encounterType,
      speciesId: speciesId,
      cellId: input.cellId,
      seed: input.seed,
    );
  }
}
