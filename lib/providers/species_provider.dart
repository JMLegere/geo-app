import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/species_repo.dart';
import 'package:earth_nova/domain/species/species_cache.dart';
import 'package:earth_nova/domain/species/species_repository.dart';
import 'package:earth_nova/models/continent.dart';
import 'package:earth_nova/models/habitat.dart';
import 'package:earth_nova/models/item_definition.dart';
import 'package:earth_nova/models/iucn_status.dart';
import 'package:earth_nova/providers/database_provider.dart';

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final speciesRepoProvider = Provider<SpeciesRepo>(
  (ref) => SpeciesRepo(ref.watch(databaseProvider)),
);

final speciesCacheProvider = Provider<SpeciesCache>((ref) {
  final repo = ref.watch(speciesRepoProvider);
  return SpeciesCache(_DriftSpeciesRepository(repo));
});

// ---------------------------------------------------------------------------
// Adapter: SpeciesRepo (Drift) → SpeciesRepository (domain)
// ---------------------------------------------------------------------------

/// Converts Drift [Species] rows to domain [FaunaDefinition] objects so that
/// [SpeciesCache] can operate against the typed domain interface.
class _DriftSpeciesRepository implements SpeciesRepository {
  final SpeciesRepo _repo;
  _DriftSpeciesRepository(this._repo);

  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    final rows = await _repo.getCandidates(
      habitats: habitats.map((h) => h.name).toList(),
      continent: continent.name,
    );
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<FaunaDefinition>> getByIds(List<String> ids) async {
    // SpeciesRepo has no batch-by-id method — fetch individually.
    final futures = ids.map(_repo.getById);
    final results = await Future.wait(futures);
    return results.whereType<Species>().map(_toDomain).toList();
  }

  @override
  Future<int> count() => _repo.count();

  static FaunaDefinition _toDomain(Species s) {
    List<Habitat> habitats;
    try {
      habitats = (jsonDecode(s.habitatsJson) as List)
          .whereType<String>()
          .map((name) => Habitat.values.firstWhere(
                (h) => h.name == name,
                orElse: () => Habitat.plains,
              ))
          .toList();
    } catch (_) {
      habitats = const [Habitat.plains];
    }

    List<Continent> continents;
    try {
      continents = (jsonDecode(s.continentsJson) as List)
          .whereType<String>()
          .map((name) => Continent.values.firstWhere(
                (c) => c.name == name,
                orElse: () => Continent.asia,
              ))
          .toList();
    } catch (_) {
      continents = const [];
    }

    final rarity = IucnStatus.values.firstWhereOrNull(
          (r) => r.name == s.iucnStatus,
        ) ??
        IucnStatus.leastConcern;

    return FaunaDefinition(
      id: s.definitionId,
      displayName: s.commonName,
      scientificName: s.scientificName,
      taxonomicClass: s.taxonomicClass,
      rarity: rarity,
      habitats: habitats,
      continents: continents,
      brawn: s.brawn,
      wit: s.wit,
      speed: s.speed,
      size: s.size,
      iconUrl: s.iconUrl,
      artUrl: s.artUrl,
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}
