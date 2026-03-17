import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_repository.dart';

Future<SpeciesRepository> createRepository() async {
  return StubSpeciesRepository();
}

class StubSpeciesRepository implements SpeciesRepository {
  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async =>
      const [];

  @override
  Future<FaunaDefinition?> getByScientificName(String name) async => null;

  @override
  Future<int> count() async => 0;

  @override
  Future<List<FaunaDefinition>> getAll() async => const [];

  @override
  void dispose() {}
}
