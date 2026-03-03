import 'dart:convert';

import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/species.dart';

/// Loads and filters SpeciesRecord data from the bundled IUCN species JSON.
///
/// The JSON asset is at assets/species_data.json (32,752 records).
/// For testability, the primary entry point accepts a raw JSON string,
/// so tests can pass a small fixture without rootBundle.
///
/// Records with "Unknown" habitats or continents are silently skipped
/// during loading.
class SpeciesDataLoader {
  static List<SpeciesRecord> fromJsonString(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    final records = <SpeciesRecord>[];
    for (final e in list) {
      try {
        final record = SpeciesRecord.fromJson(e as Map<String, dynamic>);
        records.add(record);
      } on ArgumentError {
        // Skip records with unknown habitats, continents, or IUCN statuses.
      }
    }
    return records;
  }

  /// Filter records by habitat.
  static List<SpeciesRecord> forHabitat(
      List<SpeciesRecord> all, Habitat habitat) {
    return all.where((s) => s.habitats.contains(habitat)).toList();
  }

  /// Filter records by continent.
  static List<SpeciesRecord> forContinent(
      List<SpeciesRecord> all, Continent continent) {
    return all.where((s) => s.continents.contains(continent)).toList();
  }

  /// Filter by habitat AND continent.
  static List<SpeciesRecord> forHabitatAndContinent(
    List<SpeciesRecord> all,
    Habitat habitat,
    Continent continent,
  ) {
    return all
        .where((s) =>
            s.habitats.contains(habitat) && s.continents.contains(continent))
        .toList();
  }
}
