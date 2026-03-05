import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/persistence/collection_repository.dart';
import 'test_helpers.dart';

void main() {
  group('CollectionRepository', () {
    late CollectionRepository repo;

    setUp(() async {
      final db = createTestDatabase();
      repo = CollectionRepository(db);
    });

    test('add and check species collection', () async {
      const userId = 'user123';
      const speciesId = 'species456';
      const cellId = 'cell789';

      // Add species
      await repo.addSpecies(
        id: 'collection1',
        userId: userId,
        speciesId: speciesId,
        cellId: cellId,
      );

      // Check if collected
      final isCollected = await repo.isCollected(userId, speciesId, cellId);

      expect(isCollected, true);
    });

    test('remove species from collection', () async {
      const userId = 'user123';
      const speciesId = 'species456';
      const cellId = 'cell789';

      // Add species
      await repo.addSpecies(
        id: 'collection1',
        userId: userId,
        speciesId: speciesId,
        cellId: cellId,
      );

      // Remove species
      final deleted = await repo.removeSpecies(userId, speciesId, cellId);

      expect(deleted, 1);

      // Verify removed
      final isCollected = await repo.isCollected(userId, speciesId, cellId);
      expect(isCollected, false);
    });

    test('get all collected species by user', () async {
      const userId = 'user123';

      // Add multiple species
      await repo.addSpecies(
        id: 'collection1',
        userId: userId,
        speciesId: 'species1',
        cellId: 'cell1',
      );
      await repo.addSpecies(
        id: 'collection2',
        userId: userId,
        speciesId: 'species2',
        cellId: 'cell2',
      );
      await repo.addSpecies(
        id: 'collection3',
        userId: 'other_user',
        speciesId: 'species3',
        cellId: 'cell3',
      );

      // Get by user
      final collected = await repo.getCollectedByUser(userId);

      expect(collected.length, 2);
      expect(
        collected.map((c) => c.speciesId).toList(),
        ['species1', 'species2'],
      );
    });

    test('get collected species by cell', () async {
      const userId = 'user123';
      const cellId = 'cell1';

      // Add species in same cell
      await repo.addSpecies(
        id: 'collection1',
        userId: userId,
        speciesId: 'species1',
        cellId: cellId,
      );
      await repo.addSpecies(
        id: 'collection2',
        userId: userId,
        speciesId: 'species2',
        cellId: cellId,
      );

      // Add species in different cell
      await repo.addSpecies(
        id: 'collection3',
        userId: userId,
        speciesId: 'species3',
        cellId: 'cell2',
      );

      // Get by cell
      final collected = await repo.getCollectedByCell(userId, cellId);

      expect(collected.length, 2);
    });

    test('get collection count', () async {
      const userId = 'user123';

      // Add species
      for (int i = 0; i < 5; i++) {
        await repo.addSpecies(
          id: 'collection$i',
          userId: userId,
          speciesId: 'species$i',
          cellId: 'cell$i',
        );
      }

      // Get count
      final count = await repo.getCollectionCount(userId);

      expect(count, 5);
    });

    test('get unique species IDs', () async {
      const userId = 'user123';

      // Add same species in different cells
      await repo.addSpecies(
        id: 'collection1',
        userId: userId,
        speciesId: 'species1',
        cellId: 'cell1',
      );
      await repo.addSpecies(
        id: 'collection2',
        userId: userId,
        speciesId: 'species1',
        cellId: 'cell2',
      );
      await repo.addSpecies(
        id: 'collection3',
        userId: userId,
        speciesId: 'species2',
        cellId: 'cell3',
      );

      // Get unique IDs
      final uniqueIds = await repo.getUniqueSpeciesIds(userId);

      expect(uniqueIds.length, 2);
      expect(uniqueIds.toSet(), {'species1', 'species2'});
    });

    test('clear user collections', () async {
      const userId = 'user123';

      // Add species
      for (int i = 0; i < 3; i++) {
        await repo.addSpecies(
          id: 'collection$i',
          userId: userId,
          speciesId: 'species$i',
          cellId: 'cell$i',
        );
      }

      // Clear
      final deleted = await repo.clearUserCollections(userId);

      expect(deleted, 3);

      // Verify cleared
      final collected = await repo.getCollectedByUser(userId);
      expect(collected.length, 0);
    });

    test('concurrent adds do not lose data', () async {
      const userId = 'user123';

      // Add 100 species concurrently
      final futures = <Future<void>>[];
      for (int i = 0; i < 100; i++) {
        futures.add(
          repo.addSpecies(
            id: 'collection$i',
            userId: userId,
            speciesId: 'species$i',
            cellId: 'cell$i',
          ),
        );
      }

      await Future.wait(futures);

      // Verify all were added
      final collected = await repo.getCollectedByUser(userId);
      expect(collected.length, 100);
    });

    test('is collected returns false for non-existent species', () async {
      const userId = 'user123';

      final isCollected =
          await repo.isCollected(userId, 'nonexistent', 'nonexistent');

      expect(isCollected, false);
    });
  });
}
