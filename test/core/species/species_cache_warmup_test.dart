import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_cache.dart';
import 'package:earth_nova/core/species/species_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal mock species repository that tracks queries.
class MockSpeciesRepository implements SpeciesRepository {
  int queryCount = 0;
  final Set<String> queriedKeys = {};

  @override
  Future<List<FaunaDefinition>> getCandidates({
    required Set<Habitat> habitats,
    required Continent continent,
  }) async {
    queryCount++;
    final key = SpeciesCache.cacheKey(habitats, continent);
    queriedKeys.add(key);
    // Return one fake species per query
    return [
      FaunaDefinition(
        id: 'fauna_test_$key',
        displayName: 'Test $key',
        scientificName: 'Testus ${key.replaceAll(':', '_')}',
        taxonomicClass: 'Mammalia',
        continents: [continent],
        habitats: habitats.toList(),
        rarity: IucnStatus.leastConcern,
      ),
    ];
  }

  @override
  Future<List<FaunaDefinition>> getAll() async => [];

  @override
  Future<int> count() async => 1;

  @override
  Future<List<FaunaDefinition>> getByIds(List<String> ids) async => [];

  @override
  Future<FaunaDefinition?> getByScientificName(String name) async => null;

  @override
  void dispose() {}
}

void main() {
  group('SpeciesCache', () {
    late MockSpeciesRepository repo;
    late SpeciesCache cache;

    setUp(() {
      repo = MockSpeciesRepository();
      cache = SpeciesCache(repo);
    });

    group('cacheKey', () {
      test('produces stable order-independent keys', () {
        final key1 = SpeciesCache.cacheKey(
            {Habitat.forest, Habitat.plains}, Continent.northAmerica);
        final key2 = SpeciesCache.cacheKey(
            {Habitat.plains, Habitat.forest}, Continent.northAmerica);
        expect(key1, equals(key2));
      });

      test('different continents produce different keys', () {
        final key1 =
            SpeciesCache.cacheKey({Habitat.forest}, Continent.northAmerica);
        final key2 = SpeciesCache.cacheKey({Habitat.forest}, Continent.europe);
        expect(key1, isNot(equals(key2)));
      });

      test('different habitats produce different keys', () {
        final key1 =
            SpeciesCache.cacheKey({Habitat.forest}, Continent.northAmerica);
        final key2 =
            SpeciesCache.cacheKey({Habitat.plains}, Continent.northAmerica);
        expect(key1, isNot(equals(key2)));
      });

      test('multi-habitat key is sorted alphabetically', () {
        final key = SpeciesCache.cacheKey(
            {Habitat.swamp, Habitat.desert, Habitat.forest}, Continent.africa);
        expect(key, equals('desert,forest,swamp:africa'));
      });
    });

    group('warmUp', () {
      test('queries repo on first call for a combo', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        expect(repo.queryCount, 1);
      });

      test('does not re-query for same combo', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        expect(repo.queryCount, 1);
      });

      test('queries for different combos', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        await cache.warmUp(
            habitats: {Habitat.plains}, continent: Continent.northAmerica);
        await cache
            .warmUp(habitats: {Habitat.forest}, continent: Continent.europe);
        expect(repo.queryCount, 3);
      });

      test('no-ops for empty habitats', () async {
        await cache.warmUp(habitats: {}, continent: Continent.northAmerica);
        expect(repo.queryCount, 0);
      });
    });

    group('getCandidatesSync', () {
      test('returns empty before warmUp', () {
        final result = cache.getCandidatesSync(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        expect(result, isEmpty);
      });

      test('returns species after warmUp', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        final result = cache.getCandidatesSync(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        expect(result, hasLength(1));
        expect(result.first.id, contains('forest'));
      });

      test('returns empty for un-warmed combo even after other warmUps',
          () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        final result = cache.getCandidatesSync(
            habitats: {Habitat.plains}, continent: Continent.northAmerica);
        expect(result, isEmpty);
      });

      test('returns empty for empty habitats', () {
        final result = cache
            .getCandidatesSync(habitats: {}, continent: Continent.northAmerica);
        expect(result, isEmpty);
      });
    });

    group('refresh', () {
      test('re-queries all previously cached combos', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        await cache
            .warmUp(habitats: {Habitat.plains}, continent: Continent.europe);
        expect(repo.queryCount, 2);

        await cache.refresh();
        // Should re-query both combos
        expect(repo.queryCount, 4);
      });

      test('preserves coverage after refresh', () async {
        await cache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        await cache
            .warmUp(habitats: {Habitat.plains}, continent: Continent.europe);

        await cache.refresh();

        // Both combos should still return results
        expect(
          cache.getCandidatesSync(
              habitats: {Habitat.forest}, continent: Continent.northAmerica),
          hasLength(1),
        );
        expect(
          cache.getCandidatesSync(
              habitats: {Habitat.plains}, continent: Continent.europe),
          hasLength(1),
        );
      });
    });

    group('multi-combo warmup (the fix)', () {
      test('warming multiple combos makes all available for sync lookup',
          () async {
        // This is the exact pattern the fix uses at startup:
        // iterate all cached cell properties and warm each unique combo.
        final combos = [
          ({Habitat.forest}, Continent.northAmerica),
          ({Habitat.plains}, Continent.northAmerica),
          ({Habitat.forest, Habitat.freshwater}, Continent.northAmerica),
          ({Habitat.mountain}, Continent.europe),
        ];

        final seen = <String>{};
        for (final (habitats, continent) in combos) {
          final key = SpeciesCache.cacheKey(habitats, continent);
          if (seen.add(key)) {
            await cache.warmUp(habitats: habitats, continent: continent);
          }
        }

        expect(repo.queryCount, 4);

        // Every combo should now return results
        for (final (habitats, continent) in combos) {
          final result =
              cache.getCandidatesSync(habitats: habitats, continent: continent);
          expect(result, isNotEmpty,
              reason:
                  'Expected results for ${SpeciesCache.cacheKey(habitats, continent)}');
        }
      });

      test('deduplicates identical combos', () async {
        final combos = [
          ({Habitat.forest}, Continent.northAmerica),
          ({Habitat.forest}, Continent.northAmerica), // duplicate
          ({Habitat.plains}, Continent.northAmerica),
          ({Habitat.plains}, Continent.northAmerica), // duplicate
        ];

        final seen = <String>{};
        for (final (habitats, continent) in combos) {
          final key = SpeciesCache.cacheKey(habitats, continent);
          if (seen.add(key)) {
            await cache.warmUp(habitats: habitats, continent: continent);
          }
        }

        // Only 2 unique combos → only 2 queries
        expect(repo.queryCount, 2);
      });
    });

    group('SpeciesCache.empty', () {
      test('isEmpty returns true', () {
        final emptyCache = SpeciesCache.empty();
        expect(emptyCache.isEmpty, isTrue);
      });

      test('warmUp is no-op', () async {
        final emptyCache = SpeciesCache.empty();
        await emptyCache.warmUp(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        final result = emptyCache.getCandidatesSync(
            habitats: {Habitat.forest}, continent: Continent.northAmerica);
        expect(result, isEmpty);
      });
    });
  });
}
