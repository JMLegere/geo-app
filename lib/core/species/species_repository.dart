import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';

/// Repository for querying species data.
///
/// On native platforms, backed by Drift's [LocalSpeciesTable].
/// Use [DriftSpeciesRepository] as the concrete implementation.
abstract class SpeciesRepository {
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  });

  Future<FaunaDefinition?> getByScientificName(String name);

  /// Batch-fetch species by definition IDs.
  Future<List<FaunaDefinition>> getByIds(List<String> ids);

  Future<int> count();

  Future<List<FaunaDefinition>> getAll();

  void dispose();
}
