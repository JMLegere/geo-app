import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';

// Conditional import — native gets FFI sqlite3, web gets stub
import 'species_repository_stub.dart'
    if (dart.library.io) 'species_repository_native.dart' as platform;

/// Repository for querying the pre-compiled species SQLite database.
///
/// On native platforms, opens `assets/species.db` via sqlite3 FFI.
/// On web, returns an empty stub (web uses SpeciesService fallback).
abstract class SpeciesRepository {
  /// Opens species.db from Flutter assets (native) or returns stub (web).
  static Future<SpeciesRepository> fromAssets() => platform.createRepository();

  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  });

  Future<FaunaDefinition?> getByScientificName(String name);

  Future<int> count();

  Future<List<FaunaDefinition>> getAll();

  void dispose();
}
