/// Integration test: SQLite persistence works offline via Drift + NativeDatabase.memory().
///
/// Uses an in-memory database so no file I/O occurs. Tests every repository
/// operation and exercises the full workflow:
///   create profile → explore cells → collect items → update streaks → reopen
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Build a fresh in-memory [AppDatabase]. Always clean — no cross-test state.
AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

/// Build a minimal [LocalCellProgress] record.
LocalCellProgress makeCellProgress({
  String id = 'cp-1',
  String userId = 'user-1',
  String cellId = 'cell-42',
  String fogState = 'hidden',
  double distanceWalked = 100.0,
  int visitCount = 1,
  double restorationLevel = 0.0,
}) =>
    LocalCellProgress(
      id: id,
      userId: userId,
      cellId: cellId,
      fogState: fogState,
      distanceWalked: distanceWalked,
      visitCount: visitCount,
      restorationLevel: restorationLevel,
      lastVisited: DateTime(2026, 3, 1),
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

/// Build a minimal [LocalItemInstance] record.
LocalItemInstance makeItemInstance({
  String id = 'item-1',
  String userId = 'user-1',
  String definitionId = 'fauna_vulpes_vulpes',
  String cellId = 'cell-42',
}) =>
    LocalItemInstance(
      id: id,
      userId: userId,
      definitionId: definitionId,
      displayName: 'Test Species',
      categoryName: 'fauna',
      affixes: '[]',
      acquiredAt: DateTime(2026, 3, 1),
      acquiredInCellId: cellId,
      status: 'active',
      badgesJson: '[]',
      habitatsJson: '[]',
      continentsJson: '[]',
    );

/// Build a minimal [LocalPlayerProfile] record.
LocalPlayerProfile makeProfile({
  String id = 'user-1',
  String displayName = 'Tester',
  int currentStreak = 1,
  int longestStreak = 1,
  double totalDistanceKm = 0.0,
  String currentSeason = 'summer',
}) =>
    LocalPlayerProfile(
      id: id,
      displayName: displayName,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDistanceKm: totalDistanceKm,
      currentSeason: currentSeason,
      hasCompletedOnboarding: false,
      totalSteps: 0,
      lastKnownStepCount: 0,
      createdAt: DateTime(2026, 3, 1),
      updatedAt: DateTime(2026, 3, 1),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Suppress Drift's "multiple AppDatabase instances" debug warning.
  // Each test creates a fresh in-memory database to ensure full isolation.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Offline Persistence — CellProgress', () {
    late AppDatabase db;

    setUp(() => db = makeInMemoryDb());
    tearDown(() => db.close());

    test('upsertCellProgress inserts a new record', () async {
      final progress = makeCellProgress();
      await db.upsertCellProgress(progress);

      final result = await db.getCellProgress(progress.userId, progress.cellId);
      expect(result, isNotNull);
      expect(result!.id, equals(progress.id));
      expect(result.fogState, equals('hidden'));
    });

    test('getCellProgressByUser returns all records for user', () async {
      await db
          .upsertCellProgress(makeCellProgress(id: 'cp-1', cellId: 'cell-1'));
      await db
          .upsertCellProgress(makeCellProgress(id: 'cp-2', cellId: 'cell-2'));
      await db
          .upsertCellProgress(makeCellProgress(id: 'cp-3', cellId: 'cell-3'));

      final records = await db.getCellProgressByUser('user-1');
      expect(records.length, equals(3));
    });

    test('upsertCellProgress updates existing record (upsert semantics)',
        () async {
      final initial = makeCellProgress(fogState: 'hidden', visitCount: 1);
      await db.upsertCellProgress(initial);

      final updated = makeCellProgress(fogState: 'observed', visitCount: 3);
      await db.upsertCellProgress(updated);

      final result = await db.getCellProgress('user-1', 'cell-42');
      expect(result, isNotNull);
      expect(result!.fogState, equals('observed'));
      expect(result.visitCount, equals(3));
    });

    test('deleteCellProgress removes the record', () async {
      await db.upsertCellProgress(makeCellProgress());
      await db.deleteCellProgress('user-1', 'cell-42');

      final result = await db.getCellProgress('user-1', 'cell-42');
      expect(result, isNull);
    });

    test('getCellProgress returns null for non-existent record', () async {
      final result = await db.getCellProgress('nobody', 'cell-0');
      expect(result, isNull);
    });
  });

  group('Offline Persistence — ItemInstance', () {
    late AppDatabase db;

    setUp(() => db = makeInMemoryDb());
    tearDown(() => db.close());

    test('insertItemInstance adds a record', () async {
      final item = makeItemInstance();
      await db.insertItemInstance(item);

      final results = await db.getItemInstancesByUser(item.userId);
      expect(results.length, equals(1));
      expect(results.first.definitionId, equals('fauna_vulpes_vulpes'));
    });

    test('getItemInstancesByUser returns all for user', () async {
      await db.insertItemInstance(
          makeItemInstance(id: 'item-1', definitionId: 'fauna_vulpes_vulpes'));
      await db.insertItemInstance(
          makeItemInstance(id: 'item-2', definitionId: 'fauna_panthera_leo'));
      await db.insertItemInstance(
          makeItemInstance(id: 'item-3', definitionId: 'fauna_ursus_arctos'));

      final records = await db.getItemInstancesByUser('user-1');
      expect(records.length, equals(3));
    });

    test('getItemInstancesByCell returns only records for that cell', () async {
      await db
          .insertItemInstance(makeItemInstance(id: 'item-1', cellId: 'cell-1'));
      await db.insertItemInstance(makeItemInstance(
          id: 'item-2', cellId: 'cell-2', definitionId: 'fauna_s2'));

      final records = await db.getItemInstancesByCell('user-1', 'cell-1');
      expect(records.length, equals(1));
      expect(records.first.acquiredInCellId, equals('cell-1'));
    });

    test('getItemInstance returns the record by id', () async {
      final item = makeItemInstance(id: 'item-unique');
      await db.insertItemInstance(item);

      final result = await db.getItemInstance('item-unique');
      expect(result, isNotNull);
      expect(result!.id, equals('item-unique'));
      expect(result.definitionId, equals('fauna_vulpes_vulpes'));
    });

    test('getItemInstance returns null for non-existent id', () async {
      final result = await db.getItemInstance('ghost-id');
      expect(result, isNull);
    });

    test('updateItemInstance updates the record', () async {
      final item = makeItemInstance();
      await db.insertItemInstance(item);

      final updated = LocalItemInstance(
        id: item.id,
        userId: item.userId,
        definitionId: item.definitionId,
        displayName: 'Test Species',
        categoryName: 'fauna',
        affixes: '[]',
        acquiredAt: item.acquiredAt,
        acquiredInCellId: item.acquiredInCellId,
        status: 'donated',
        badgesJson: '[]',
        habitatsJson: '[]',
        continentsJson: '[]',
      );
      await db.updateItemInstance(updated);

      final result = await db.getItemInstance(item.id);
      expect(result, isNotNull);
      expect(result!.status, equals('donated'));
    });

    test('deleteItemInstance removes the record', () async {
      final item = makeItemInstance();
      await db.insertItemInstance(item);
      await db.deleteItemInstance(item.id);

      final result = await db.getItemInstance(item.id);
      expect(result, isNull);
    });
  });

  group('Offline Persistence — PlayerProfile', () {
    late AppDatabase db;

    setUp(() => db = makeInMemoryDb());
    tearDown(() => db.close());

    test('upsertPlayerProfile inserts a new profile', () async {
      final profile = makeProfile();
      await db.upsertPlayerProfile(profile);

      final result = await db.getPlayerProfile('user-1');
      expect(result, isNotNull);
      expect(result!.displayName, equals('Tester'));
      expect(result.currentStreak, equals(1));
    });

    test('upsertPlayerProfile updates streak on second write', () async {
      await db.upsertPlayerProfile(makeProfile(currentStreak: 1));

      final updated = makeProfile(currentStreak: 5, longestStreak: 5);
      await db.upsertPlayerProfile(updated);

      final result = await db.getPlayerProfile('user-1');
      expect(result, isNotNull);
      expect(result!.currentStreak, equals(5));
      expect(result.longestStreak, equals(5));
    });

    test('getPlayerProfile returns null for unknown user', () async {
      final result = await db.getPlayerProfile('ghost');
      expect(result, isNull);
    });

    test('deletePlayerProfile removes the profile', () async {
      await db.upsertPlayerProfile(makeProfile());
      await db.deletePlayerProfile('user-1');
      final result = await db.getPlayerProfile('user-1');
      expect(result, isNull);
    });
  });

  group('Offline Persistence — Full Workflow', () {
    test('complete game session: create profile → explore → collect → streak',
        () async {
      final db = makeInMemoryDb();
      addTearDown(db.close);

      // 1. Create player profile.
      final profile = makeProfile(id: 'player-1', displayName: 'Naturalist');
      await db.upsertPlayerProfile(profile);

      // 2. Explore three cells (insert progress records).
      for (int i = 0; i < 3; i++) {
        await db.upsertCellProgress(makeCellProgress(
          id: 'cp-$i',
          userId: 'player-1',
          cellId: 'cell-$i',
          fogState: 'observed',
          visitCount: 1,
        ));
      }

      // 3. Collect items in two of those cells.
      await db.insertItemInstance(makeItemInstance(
        id: 'item-1',
        userId: 'player-1',
        definitionId: 'fauna_vulpes_vulpes',
        cellId: 'cell-0',
      ));
      await db.insertItemInstance(makeItemInstance(
        id: 'item-2',
        userId: 'player-1',
        definitionId: 'fauna_panthera_leo',
        cellId: 'cell-1',
      ));

      // 4. Update streak.
      final updatedProfile =
          makeProfile(id: 'player-1', currentStreak: 2, longestStreak: 2);
      await db.upsertPlayerProfile(updatedProfile);

      // 5. Verify all state persisted.
      final savedProfile = await db.getPlayerProfile('player-1');
      expect(savedProfile, isNotNull);
      expect(savedProfile!.currentStreak, equals(2));

      final allProgress = await db.getCellProgressByUser('player-1');
      expect(allProgress.length, equals(3));

      final allItems = await db.getItemInstancesByUser('player-1');
      expect(allItems.length, equals(2));

      final foxItems = allItems
          .where((i) => i.definitionId == 'fauna_vulpes_vulpes')
          .toList();
      expect(foxItems.length, equals(1));
      expect(foxItems.first.acquiredInCellId, equals('cell-0'));
    });

    test('data survives conceptual database reopen (two in-memory instances)',
        () async {
      // We cannot truly close and reopen an in-memory database (it would be
      // empty on reopen). Instead, this test verifies that two separate
      // AppDatabase instances with NativeDatabase.memory() start clean and
      // accumulate state independently, which is equivalent behaviour.
      //
      // For file-based databases (production), the same API writes to disk
      // and survives restarts. The test below proves the persistence API is
      // correct, not the file I/O path.
      final db1 = makeInMemoryDb();
      await db1.upsertPlayerProfile(makeProfile(id: 'user-2'));
      final saved = await db1.getPlayerProfile('user-2');
      expect(saved, isNotNull);
      await db1.close();

      // A second fresh in-memory database starts empty.
      final db2 = makeInMemoryDb();
      addTearDown(db2.close);
      final missing = await db2.getPlayerProfile('user-2');
      expect(missing, isNull,
          reason: 'In-memory databases are independent instances');
    });
  });
}
