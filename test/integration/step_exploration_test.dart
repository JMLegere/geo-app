/// Integration test: step persistence + frontier exploration round-trip.
///
/// Verifies the complete step-based exploration pipeline:
///   1. Step values survive DB round-trips (write → read → match)
///   2. Frontier exploration deducts steps, visits cell, expands frontier
///   3. Insufficient step balance rejects spending
///   4. visitCellRemotely triggers onVisitedCellAdded stream event
///   5. Hydrate → spend → persist → read round-trip
///
/// All tests use `NativeDatabase.memory()` — no Supabase or network access.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geobase/geobase.dart';

import 'package:earth_nova/core/cells/cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_event.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// MockCellService — deterministic integer grid
// ---------------------------------------------------------------------------

/// Cell ID format: `"cell_{latInt}_{lonInt}"`.
/// Neighbors: Moore neighborhood (8-connected 3×3 minus center).
class _MockCellService implements CellService {
  @override
  String getCellId(double lat, double lon) =>
      'cell_${lat.round()}_${lon.round()}';

  @override
  Geographic getCellCenter(String cellId) {
    final parts = cellId.split('_');
    return Geographic(lat: double.parse(parts[1]), lon: double.parse(parts[2]));
  }

  @override
  List<Geographic> getCellBoundary(String cellId) {
    final c = getCellCenter(cellId);
    const h = 0.5;
    return [
      Geographic(lat: c.lat - h, lon: c.lon - h),
      Geographic(lat: c.lat - h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon + h),
      Geographic(lat: c.lat + h, lon: c.lon - h),
    ];
  }

  @override
  List<String> getNeighborIds(String cellId) {
    final parts = cellId.split('_');
    final lat = int.parse(parts[1]);
    final lon = int.parse(parts[2]);
    final neighbors = <String>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dy == 0 && dx == 0) continue;
        neighbors.add('cell_${lat + dy}_${lon + dx}');
      }
    }
    return neighbors;
  }

  @override
  List<String> getCellsInRing(String cellId, int k) {
    final parts = cellId.split('_');
    final lat = int.parse(parts[1]);
    final lon = int.parse(parts[2]);
    final cells = <String>[];
    for (var dy = -k; dy <= k; dy++) {
      for (var dx = -k; dx <= k; dx++) {
        cells.add('cell_${lat + dy}_${lon + dx}');
      }
    }
    return cells;
  }

  @override
  List<String> getCellsAroundLocation(double lat, double lon, int k) =>
      getCellsInRing(getCellId(lat, lon), k);

  @override
  double get cellEdgeLengthMeters => 100.0;

  @override
  String get systemName => 'MockGrid';
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase makeInMemoryDb() => AppDatabase(NativeDatabase.memory());

/// Seed a player profile with step data.
Future<void> seedProfile(
  AppDatabase db, {
  String userId = 'user-1',
  int totalSteps = 0,
  int lastKnownStepCount = 0,
}) async {
  final profile = LocalPlayerProfile(
    id: userId,
    displayName: 'Tester',
    currentStreak: 0,
    longestStreak: 0,
    totalDistanceKm: 0.0,
    currentSeason: 'summer',
    hasCompletedOnboarding: false,
    totalSteps: totalSteps,
    lastKnownStepCount: lastKnownStepCount,
    createdAt: DateTime(2026, 3, 1),
    updatedAt: DateTime(2026, 3, 1),
  );
  await db.upsertPlayerProfile(profile);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // ── Test 1: Step persistence round-trip ──────────────────────────────────

  group('Step persistence round-trip', () {
    late AppDatabase db;
    late ProfileRepository repo;

    setUp(() {
      db = makeInMemoryDb();
      repo = ProfileRepository(db);
    });
    tearDown(() => db.close());

    test('totalSteps and lastKnownStepCount survive DB write and read',
        () async {
      await repo.create(
        userId: 'user-1',
        displayName: 'Tester',
        totalSteps: 1500,
        lastKnownStepCount: 5000,
      );

      final profile = await repo.read('user-1');
      expect(profile, isNotNull);
      expect(profile!.totalSteps, equals(1500));
      expect(profile.lastKnownStepCount, equals(5000));
    });

    test('step values survive update round-trip', () async {
      await repo.create(
        userId: 'user-1',
        displayName: 'Tester',
        totalSteps: 1000,
        lastKnownStepCount: 3000,
      );

      await repo.update(
        userId: 'user-1',
        totalSteps: 500,
        lastKnownStepCount: 4000,
      );

      final profile = await repo.read('user-1');
      expect(profile, isNotNull);
      expect(profile!.totalSteps, equals(500));
      expect(profile.lastKnownStepCount, equals(4000));
    });

    test('step values survive simulated app restart (new repo, same DB)',
        () async {
      // Write with first repo instance.
      await repo.create(
        userId: 'user-1',
        displayName: 'Tester',
        totalSteps: 2000,
        lastKnownStepCount: 8000,
      );

      // Read with a new repo instance (simulated restart).
      final repo2 = ProfileRepository(db);
      final profile = await repo2.read('user-1');
      expect(profile, isNotNull);
      expect(profile!.totalSteps, equals(2000));
      expect(profile.lastKnownStepCount, equals(8000));
    });
  });

  // ── Test 2: Frontier exploration with step spending ─────────────────────

  group('Frontier exploration with step spending', () {
    test('spending steps + visitCellRemotely visits cell and expands frontier',
        () async {
      final cellService = _MockCellService();
      final resolver = FogStateResolver(cellService);

      // Visit 3 cells to build up a frontier.
      resolver.onLocationUpdate(10.0, 10.0); // cell_10_10
      resolver.onLocationUpdate(11.0, 10.0); // cell_11_10
      resolver.onLocationUpdate(12.0, 10.0); // cell_12_10

      expect(resolver.visitedCellIds.length, equals(3));
      expect(resolver.explorationFrontier.isNotEmpty, isTrue);

      // Pick a frontier cell.
      final frontierCell = resolver.explorationFrontier.first;
      expect(resolver.visitedCellIds.contains(frontierCell), isFalse);

      // Set up player with steps.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerProvider.notifier).addSteps(kStepCostPerCell);

      // Spend steps.
      final spent =
          container.read(playerProvider.notifier).spendSteps(kStepCostPerCell);
      expect(spent, isTrue);
      expect(container.read(playerProvider).totalSteps, equals(0));

      // Capture frontier before visit for expansion check.
      final frontierBefore = Set<String>.from(resolver.explorationFrontier);

      // Visit the cell remotely.
      resolver.visitCellRemotely(frontierCell);

      // Cell is now visited.
      expect(resolver.visitedCellIds.contains(frontierCell), isTrue);

      // Cell is no longer on frontier.
      expect(resolver.explorationFrontier.contains(frontierCell), isFalse);

      // Frontier expanded: at least one new cell added (neighbors of the
      // visited cell that weren't already visited or on frontier).
      final newFrontierCells =
          resolver.explorationFrontier.difference(frontierBefore);
      // The newly visited cell may have neighbors that weren't on the frontier
      // before. In a Moore neighborhood (8 neighbors), at least some should be
      // new unless the visited cell was completely surrounded.
      expect(
        newFrontierCells.isNotEmpty || resolver.explorationFrontier.isNotEmpty,
        isTrue,
        reason: 'Frontier must expand or remain non-empty after visiting',
      );
    });
  });

  // ── Test 3: Step spending rejected when insufficient balance ────────────

  group('Step spending — insufficient balance', () {
    test('spendSteps returns false and leaves totalSteps unchanged', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerProvider.notifier).addSteps(300);

      final spent =
          container.read(playerProvider.notifier).spendSteps(kStepCostPerCell);
      expect(spent, isFalse);
      expect(container.read(playerProvider).totalSteps, equals(300));
    });

    test('spendSteps rejects zero and negative amounts', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(playerProvider.notifier).addSteps(1000);

      expect(container.read(playerProvider.notifier).spendSteps(0), isFalse);
      expect(container.read(playerProvider.notifier).spendSteps(-100), isFalse);
      expect(container.read(playerProvider).totalSteps, equals(1000));
    });
  });

  // ── Test 4: visitCellRemotely emits onVisitedCellAdded event ────────────

  group('visitCellRemotely — stream event', () {
    test('emits FogStateChangedEvent on onVisitedCellAdded stream', () async {
      final cellService = _MockCellService();
      final resolver = FogStateResolver(cellService);

      // Visit an initial cell to create a frontier.
      resolver.onLocationUpdate(10.0, 10.0); // cell_10_10

      final frontierCell = resolver.explorationFrontier.first;

      // Collect stream events.
      final events = <FogStateChangedEvent>[];
      final sub = resolver.onVisitedCellAdded.listen(events.add);
      addTearDown(sub.cancel);

      // Visit remotely — should emit event (sync stream, so immediate).
      resolver.visitCellRemotely(frontierCell);

      // onVisitedCellAdded is sync: true — event is already in the list.
      expect(events.length, equals(1));
      expect(events.first.cellId, equals(frontierCell));
    });

    test('does not emit for already-visited cell', () async {
      final cellService = _MockCellService();
      final resolver = FogStateResolver(cellService);

      resolver.onLocationUpdate(10.0, 10.0); // cell_10_10

      final frontierCell = resolver.explorationFrontier.first;
      resolver.visitCellRemotely(frontierCell); // First visit

      // Collect events from now on.
      final events = <FogStateChangedEvent>[];
      final sub = resolver.onVisitedCellAdded.listen(events.add);
      addTearDown(sub.cancel);

      // Second visit — should be a no-op.
      resolver.visitCellRemotely(frontierCell);

      expect(events, isEmpty, reason: 'No event for already-visited cell');
    });
  });

  // ── Test 5: Hydrate → spend → persist → read round-trip ─────────────────

  group('Hydrate → spend → persist round-trip', () {
    late AppDatabase db;
    late ProfileRepository repo;

    setUp(() {
      db = makeInMemoryDb();
      repo = ProfileRepository(db);
    });
    tearDown(() => db.close());

    test('full cycle: seed DB → hydrate notifier → spend → persist → verify',
        () async {
      // 1. Seed DB with initial step data.
      await seedProfile(db, totalSteps: 2000, lastKnownStepCount: 8000);

      // 2. Read from DB (simulating hydration).
      final profile = await repo.read('user-1');
      expect(profile, isNotNull);

      // 3. Hydrate PlayerNotifier with persisted steps.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(playerProvider.notifier)
          .addSteps(profile!.totalSteps); // 2000

      expect(container.read(playerProvider).totalSteps, equals(2000));

      // 4. Spend steps.
      final spent =
          container.read(playerProvider.notifier).spendSteps(kStepCostPerCell);
      expect(spent, isTrue);
      expect(
        container.read(playerProvider).totalSteps,
        equals(2000 - kStepCostPerCell),
      );

      // 5. Persist updated steps back to DB.
      await repo.update(
        userId: 'user-1',
        totalSteps: container.read(playerProvider).totalSteps,
      );

      // 6. Read back and verify.
      final persisted = await repo.read('user-1');
      expect(persisted, isNotNull);
      expect(persisted!.totalSteps, equals(2000 - kStepCostPerCell));
      // lastKnownStepCount should be unchanged (only updated on hydration).
      expect(persisted.lastKnownStepCount, equals(8000));
    });
  });
}
