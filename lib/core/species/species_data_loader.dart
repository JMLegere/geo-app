import 'dart:convert';

import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';

/// Loads and filters FaunaDefinition data from the bundled IUCN species JSON.
///
/// The JSON asset is at assets/species_data.json (32,752 records).
/// For testability, the primary entry point accepts a raw JSON string,
/// so tests can pass a small fixture without rootBundle.
///
/// Records with "Unknown" habitats or continents are silently skipped
/// during loading.
class SpeciesDataLoader {
  static List<FaunaDefinition> fromJsonString(String jsonString) {
    final list = jsonDecode(jsonString) as List;
    final records = <FaunaDefinition>[];
    for (final e in list) {
      try {
        final record = FaunaDefinition.fromJson(e as Map<String, dynamic>);
        records.add(record);
      } on ArgumentError {
        // Skip records with unknown habitats, continents, or IUCN statuses.
      }
    }
    return records;
  }

  /// Filter records by habitat.
  static List<FaunaDefinition> forHabitat(
      List<FaunaDefinition> all, Habitat habitat) {
    return all.where((s) => s.habitats.contains(habitat)).toList();
  }

  /// Filter records by continent.
  static List<FaunaDefinition> forContinent(
      List<FaunaDefinition> all, Continent continent) {
    return all.where((s) => s.continents.contains(continent)).toList();
  }

  /// Filter by habitat AND continent.
  static List<FaunaDefinition> forHabitatAndContinent(
    List<FaunaDefinition> all,
    Habitat habitat,
    Continent continent,
  ) {
    return all
        .where((s) =>
            s.habitats.contains(habitat) && s.continents.contains(continent))
        .toList();
  }
}
