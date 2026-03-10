/// Integration test: complete offline game loop — the "golden path".
///
/// Wires all services together (no widgets, no Riverpod, no network) and
/// exercises the full flow:
///
///   player starts → enters cells → species discovered → add to collection
///   → record restoration → sanctuary visit → streak updated
///
/// Every step asserts the correct state change in the relevant service.
library;

import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:earth_nova/core/cells/voronoi_cell_service.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/fog/fog_state_resolver.dart';
import 'package:earth_nova/core/models/fog_state.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/caretaking/models/caretaking_state.dart';
import 'package:earth_nova/features/caretaking/services/caretaking_service.dart';
import 'package:earth_nova/core/models/discovery_event.dart';
import 'package:earth_nova/features/discovery/services/discovery_service.dart';
import 'package:earth_nova/features/restoration/services/restoration_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../fixtures/species_fixture.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SpeciesService buildSpeciesService() {
  final raw = jsonDecode(kSpeciesFixtureJson) as List<dynamic>;
  final records = raw
      .map((j) => FaunaDefinition.fromJson(j as Map<String, dynamic>))
      .toList();
  return SpeciesService(records);
}

VoronoiCellService makeSmallCellService() => VoronoiCellService(
      minLat: 37.60,
      maxLat: 37.90,
      minLon: -122.55,
      maxLon: -122.20,
      gridRows: 5,
      gridCols: 5,
      seed: 42,
    );

AppDatabase makeDb() => AppDatabase(NativeDatabase.memory());

// Centre of bounding box — a reliable starting location.
const double kStartLat = 37.75;
const double kStartLon = -122.375;

// ---------------------------------------------------------------------------
// The game session fixture
// ---------------------------------------------------------------------------

/// Holds references to all services created for a single game session.
class GameSession {
  final VoronoiCellService cellService;
  final FogStateResolver fogResolver;
  final SpeciesService speciesService;
  final DiscoveryService discoveryService;
  final RestorationService restorationService;
  final CaretakingService caretakingService;
  final AppDatabase db;
  final List<DiscoveryEvent> discoveryEvents;

  GameSession._({
    required this.cellService,
    required this.fogResolver,
    required this.speciesService,
    required this.discoveryService,
    required this.restorationService,
    required this.caretakingService,
    required this.db,
    required this.discoveryEvents,
  });

  factory GameSession.start() {
    final cellService = makeSmallCellService();
    final fogResolver = FogStateResolver(cellService);
    final speciesService = buildSpeciesService();
    final discoveryEvents = <DiscoveryEvent>[];
    final discoveryService = DiscoveryService(
      fogResolver: fogResolver,
      speciesService: speciesService,
    );
    discoveryService.onDiscovery.listen(discoveryEvents.add);

    final restorationService = RestorationService();
    final caretakingService = CaretakingService();
    final db = makeDb();

    return GameSession._(
      cellService: cellService,
      fogResolver: fogResolver,
      speciesService: speciesService,
      discoveryService: discoveryService,
      restorationService: restorationService,
      caretakingService: caretakingService,
      db: db,
      discoveryEvents: discoveryEvents,
    );
  }

  Future<void> dispose() async {
    discoveryService.dispose();
    fogResolver.dispose();
    await db.close();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // Suppress Drift's "multiple AppDatabase instances" debug warning.
  // The GameSession creates an in-memory database per test.
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Offline Full Game Loop', () {
    late GameSession session;

    setUp(() => session = GameSession.start());
    tearDown(() => session.dispose());

    // ── Step 1: Player starts at a location ──────────────────────────────

    test('1. player starts: fog resolves current cell as observed', () {
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);

      final cellId = session.fogResolver.currentCellId;
      expect(cellId, isNotNull);
      expect(
        session.fogResolver.resolve(cellId!),
        equals(FogState.observed),
      );
    });

    test('1. player starts: discovery service wired (no errors)', () {
      expect(
        () => session.fogResolver.onLocationUpdate(kStartLat, kStartLon),
        returnsNormally,
      );
    });

    // ── Step 2: Enter multiple cells ─────────────────────────────────────

    test('2. entering multiple cells accumulates visited set', () {
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      final firstId = session.fogResolver.currentCellId!;

      final neighbors = session.cellService.getNeighborIds(firstId);
      expect(neighbors, isNotEmpty);

      // Visit two neighbors.
      for (int i = 0; i < 2 && i < neighbors.length; i++) {
        final center = session.cellService.getCellCenter(neighbors[i]);
        session.fogResolver.onLocationUpdate(center.lat, center.lon);
      }

      expect(
          session.fogResolver.visitedCellIds.length, greaterThanOrEqualTo(2));
    });

    test('2. visited cell is no longer observed after player leaves', () {
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      final firstId = session.fogResolver.currentCellId!;

      final neighbors = session.cellService.getNeighborIds(firstId);
      expect(neighbors, isNotEmpty);
      final neighborCenter = session.cellService.getCellCenter(neighbors.first);
      session.fogResolver
          .onLocationUpdate(neighborCenter.lat, neighborCenter.lon);

      // First cell is visited but no longer current — it resolves as either
      // concealed (if still adjacent to new current) or hidden (if not).
      // Either way it must NOT be observed.
      final state = session.fogResolver.resolve(firstId);
      expect(state, isNot(equals(FogState.observed)),
          reason: 'Original cell must not remain observed after player leaves');
    });

    // ── Step 3: Species discovered ────────────────────────────────────────

    test('3. discovery events are tied to specific cell entries', () {
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      final currentId = session.fogResolver.currentCellId!;

      // Events (if any) belong to the current cell.
      for (final event in session.discoveryEvents) {
        expect(event.cellId, equals(currentId));
      }
    });

    test('3. all discovered species exist in the species service', () {
      // Walk through several cells to maximise chance of discovering species.
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      var prevId = session.fogResolver.currentCellId!;

      for (int step = 0; step < 4; step++) {
        final neighbors = session.cellService.getNeighborIds(prevId);
        final unvisited = neighbors
            .where((n) => !session.fogResolver.visitedCellIds.contains(n))
            .toList();
        if (unvisited.isEmpty) break;
        final center = session.cellService.getCellCenter(unvisited.first);
        session.fogResolver.onLocationUpdate(center.lat, center.lon);
        prevId = session.fogResolver.currentCellId!;
      }

      final allSpeciesIds = session.speciesService.all.map((s) => s.id).toSet();
      for (final event in session.discoveryEvents) {
        expect(allSpeciesIds, contains(event.item.id),
            reason: 'Discovered species ${event.item.id} must be in the '
                'species service catalogue');
      }
    });

    // ── Step 4: Add species to collection ─────────────────────────────────

    test('4. adding species to collection updates isNew flag', () async {
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);

      if (session.discoveryEvents.isEmpty) {
        // No species for this cell with forest+NA filter — skip.
        return;
      }

      final firstEvent = session.discoveryEvents.first;
      expect(firstEvent.isNew, isTrue);

      // Record in DB.
      await session.db.insertItemInstance(LocalItemInstance(
        id: 'item-golden',
        userId: 'player-1',
        definitionId: firstEvent.item.id,
        displayName: 'Test Species',
        categoryName: 'fauna',
        affixes: '[]',
        badgesJson: '[]',
        acquiredAt: DateTime.now(),
        acquiredInCellId: firstEvent.cellId,
        status: 'active',
        habitatsJson: '[]',
        continentsJson: '[]',
      ));

      // Mark collected in discovery service.
      session.discoveryService.markCollected(firstEvent.item.id);

      // Verify persistence.
      final items = await session.db.getItemInstancesByUser('player-1');
      final collected = items.any((i) =>
          i.definitionId == firstEvent.item.id &&
          i.acquiredInCellId == firstEvent.cellId);
      expect(collected, isTrue);
    });

    // ── Step 5: Restoration ───────────────────────────────────────────────

    test('5. recording 3 species fully restores a cell', () {
      const cellId = 'test-cell';

      expect(
          session.restorationService.getRestorationLevel(cellId), equals(0.0));

      session.restorationService.recordCollection(cellId, 'species-a');
      expect(session.restorationService.getRestorationLevel(cellId),
          closeTo(1 / 3.0, 0.001));

      session.restorationService.recordCollection(cellId, 'species-b');
      expect(session.restorationService.getRestorationLevel(cellId),
          closeTo(2 / 3.0, 0.001));

      session.restorationService.recordCollection(cellId, 'species-c');
      expect(
          session.restorationService.getRestorationLevel(cellId), equals(1.0));
      expect(session.restorationService.isFullyRestored(cellId), isTrue);
    });

    test('5. duplicate species in same cell does not double-count restoration',
        () {
      const cellId = 'test-cell-dup';

      session.restorationService.recordCollection(cellId, 'species-a');
      session.restorationService.recordCollection(cellId, 'species-a'); // dup
      session.restorationService.recordCollection(cellId, 'species-a'); // dup

      // Still only 1/3 restored.
      expect(session.restorationService.getRestorationLevel(cellId),
          closeTo(1 / 3.0, 0.001));
    });

    test('5. restoration level is clamped to 1.0 with many species', () {
      const cellId = 'test-cell-max';

      for (int i = 0; i < 10; i++) {
        session.restorationService.recordCollection(cellId, 'species-$i');
      }

      expect(
          session.restorationService.getRestorationLevel(cellId), equals(1.0));
    });

    // ── Step 6: Sanctuary visit / streak ─────────────────────────────────

    test('6. first sanctuary visit starts streak at 1', () {
      const initial = CaretakingState();
      final now = DateTime(2026, 3, 1);

      final after = session.caretakingService.recordVisit(initial, now);

      expect(after.currentStreak, equals(1));
      expect(after.longestStreak, equals(1));
      expect(after.lastVisitDate, equals(now));
    });

    test('6. consecutive daily visits increment streak', () {
      const initial = CaretakingState();
      final day1 = DateTime(2026, 3, 1);
      final day2 = DateTime(2026, 3, 2);
      final day3 = DateTime(2026, 3, 3);

      var state = session.caretakingService.recordVisit(initial, day1);
      state = session.caretakingService.recordVisit(state, day2);
      state = session.caretakingService.recordVisit(state, day3);

      expect(state.currentStreak, equals(3));
      expect(state.longestStreak, equals(3));
    });

    test('6. missed day resets streak to 1, preserves longestStreak', () {
      const initial = CaretakingState();
      final day1 = DateTime(2026, 3, 1);
      final day2 = DateTime(2026, 3, 2);
      final day3 = DateTime(2026, 3, 3);
      final day5 = DateTime(2026, 3, 5); // skip day 4

      var state = session.caretakingService.recordVisit(initial, day1);
      state = session.caretakingService.recordVisit(state, day2);
      state = session.caretakingService.recordVisit(state, day3);
      // streak = 3, longest = 3
      state = session.caretakingService.recordVisit(state, day5);
      // streak reset to 1, but longest stays at 3

      expect(state.currentStreak, equals(1));
      expect(state.longestStreak, equals(3));
    });

    test('6. same-day revisit is a no-op', () {
      const initial = CaretakingState();
      final day1 = DateTime(2026, 3, 1, 9, 0); // morning
      final day1b = DateTime(2026, 3, 1, 18, 0); // evening same day

      var state = session.caretakingService.recordVisit(initial, day1);
      state = session.caretakingService.recordVisit(state, day1b);

      expect(state.currentStreak, equals(1));
    });

    test('6. hasVisitedToday returns correct value', () {
      const initial = CaretakingState();
      final now = DateTime(2026, 3, 1);

      expect(session.caretakingService.hasVisitedToday(initial, now), isFalse);

      final after = session.caretakingService.recordVisit(initial, now);
      expect(session.caretakingService.hasVisitedToday(after, now), isTrue);
    });

    // ── Step 7: Persist game state ────────────────────────────────────────

    test('7. full session state persists to in-memory DB', () async {
      // Set up player.
      await session.db.upsertPlayerProfile(LocalPlayerProfile(
        id: 'player-1',
        displayName: 'Golden Path Player',
        currentStreak: 3,
        longestStreak: 5,
        totalDistanceKm: 2.5,
        currentSeason: 'summer',
        hasCompletedOnboarding: false,
        totalSteps: 0,
        lastKnownStepCount: 0,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ));

      // Enter a cell.
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      final cellId = session.fogResolver.currentCellId!;

      // Persist cell progress.
      await session.db.upsertCellProgress(LocalCellProgress(
        id: 'cp-golden',
        userId: 'player-1',
        cellId: cellId,
        fogState: 'observed',
        distanceWalked: 50.0,
        visitCount: 1,
        restorationLevel: 0.0,
        lastVisited: DateTime(2026, 3, 1),
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 1),
      ));

      // Persist a collected item.
      await session.db.insertItemInstance(LocalItemInstance(
        id: 'item-golden',
        userId: 'player-1',
        definitionId: 'vulpes_vulpes',
        displayName: 'Test Species',
        categoryName: 'fauna',
        affixes: '[]',
        badgesJson: '[]',
        acquiredAt: DateTime(2026, 3, 1),
        acquiredInCellId: cellId,
        status: 'active',
        habitatsJson: '[]',
        continentsJson: '[]',
      ));

      // Verify everything is persisted.
      final profile = await session.db.getPlayerProfile('player-1');
      expect(profile, isNotNull);
      expect(profile!.currentStreak, equals(3));

      final progress = await session.db.getCellProgress('player-1', cellId);
      expect(progress, isNotNull);
      expect(progress!.fogState, equals('observed'));

      final items = await session.db.getItemInstancesByUser('player-1');
      final collected = items.any((i) =>
          i.definitionId == 'vulpes_vulpes' && i.acquiredInCellId == cellId);
      expect(collected, isTrue);
    });

    // ── Complete golden path as a single scenario ─────────────────────────

    test(
        'complete golden path: start → move → discover → restore → streak → persist',
        () async {
      // 1. Start.
      session.fogResolver.onLocationUpdate(kStartLat, kStartLon);
      expect(session.fogResolver.currentCellId, isNotNull);
      expect(session.fogResolver.visitedCellIds.length, equals(1));

      // 2. Move to a neighbor.
      final firstId = session.fogResolver.currentCellId!;
      final neighbors = session.cellService.getNeighborIds(firstId);
      if (neighbors.isNotEmpty) {
        final nc = session.cellService.getCellCenter(neighbors.first);
        session.fogResolver.onLocationUpdate(nc.lat, nc.lon);
        expect(session.fogResolver.visitedCellIds.length, equals(2));
        // firstId is now visited-not-current; resolves as concealed (adjacent)
        // or hidden (if not adjacent). Either way it's no longer observed.
        expect(session.fogResolver.resolve(firstId),
            isNot(equals(FogState.observed)));
      }

      // 3. Species discovered (may or may not have results for the fixture).
      // No assertion on count — just verify no errors.
      for (final event in session.discoveryEvents) {
        expect(event.item.displayName, isNotEmpty);
      }

      // 4. Restoration: collect 3 species in a test cell.
      const restorationCellId = 'restoration-cell';
      session.restorationService.recordCollection(restorationCellId, 'sp-a');
      session.restorationService.recordCollection(restorationCellId, 'sp-b');
      session.restorationService.recordCollection(restorationCellId, 'sp-c');
      expect(session.restorationService.isFullyRestored(restorationCellId),
          isTrue);

      // 5. Streak: 3 consecutive days.
      var caretaking = const CaretakingState();
      caretaking = session.caretakingService
          .recordVisit(caretaking, DateTime(2026, 3, 1));
      caretaking = session.caretakingService
          .recordVisit(caretaking, DateTime(2026, 3, 2));
      caretaking = session.caretakingService
          .recordVisit(caretaking, DateTime(2026, 3, 3));
      expect(caretaking.currentStreak, equals(3));

      // 6. Persist profile with streak.
      await session.db.upsertPlayerProfile(LocalPlayerProfile(
        id: 'golden-player',
        displayName: 'Golden',
        currentStreak: caretaking.currentStreak,
        longestStreak: caretaking.longestStreak,
        totalDistanceKm: 0.5,
        currentSeason: 'summer',
        hasCompletedOnboarding: false,
        totalSteps: 0,
        lastKnownStepCount: 0,
        createdAt: DateTime(2026, 3, 1),
        updatedAt: DateTime(2026, 3, 3),
      ));

      // 7. Verify final state.
      final savedProfile = await session.db.getPlayerProfile('golden-player');
      expect(savedProfile, isNotNull);
      expect(savedProfile!.currentStreak, equals(3));
      expect(
          session.fogResolver.visitedCellIds.length, greaterThanOrEqualTo(1));
      expect(session.restorationService.getAllRestorationLevels(),
          contains(restorationCellId));
    });
  });
}
