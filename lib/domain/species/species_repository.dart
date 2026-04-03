import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_definition.dart';

/// Domain-layer species data source interface.
///
/// Returns fully-typed [FaunaDefinition] domain objects. Implementations
/// may be backed by Drift (SQLite), a mock, or a future Supabase client.
abstract interface class SpeciesRepository {
  /// Returns species matching any of [habitats] AND [continent].
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  });

  /// Batch-fetch species by definition ID.
  Future<List<FaunaDefinition>> getByIds(List<String> ids);

  /// Total number of species in the database.
  Future<int> count();
}
