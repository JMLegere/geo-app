/// Integration test: Supabase → SQLite hydration on startup.
///
/// Verifies that [hydrateFromSupabase] fetches data from Supabase and populates
/// local SQLite, so the existing SQLite-based hydration path has fresh data.
///
/// Test cases:
///   1. Null persistence (Supabase not configured) → no-op
///   2. Successful hydration populates profile, cells, items, enrichments
///   3. Network error → graceful fallback (no crash, SQLite untouched)
///   4. Empty server data → no-op (fresh account)
///   5. Duplicate items handled gracefully (no crash on existing PKs)
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/animal_class.dart';
import 'package:fog_of_world/core/models/climate.dart';
import 'package:fog_of_world/core/models/food_type.dart';
import 'package:fog_of_world/core/models/item_instance.dart';
import 'package:fog_of_world/core/persistence/cell_progress_repository.dart';
import 'package:fog_of_world/core/persistence/enrichment_repository.dart';
import 'package:fog_of_world/core/persistence/item_instance_repository.dart';
import 'package:fog_of_world/core/persistence/profile_repository.dart';
import 'package:fog_of_world/core/state/game_coordinator_provider.dart';
import 'package:fog_of_world/features/sync/services/supabase_persistence.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _userId = 'hydration-test-user-123';

// ---------------------------------------------------------------------------
// Mock: SupabasePersistence
// ---------------------------------------------------------------------------

class _MockSupabasePersistence extends SupabasePersistence {
  _MockSupabasePersistence()
      : super(SupabaseClient('http://localhost:54321', 'fake-anon-key'));

  // Data to return from fetch methods.
  Map<String, dynamic>? profileData;
  List<Map<String, dynamic>> cellProgressData = [];
  List<Map<String, dynamic>> itemInstanceData = [];
  List<Map<String, dynamic>> enrichmentData = [];

  /// When true, all fetch methods throw.
  bool shouldThrow = false;
  String errorMessage = 'network error';

  @override
  Future<Map<String, dynamic>?> fetchProfile(String userId) async {
    if (shouldThrow) throw SyncException(errorMessage);
    return profileData;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCellProgress(String userId) async {
    if (shouldThrow) throw SyncException(errorMessage);
    return cellProgressData;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchItemInstances(String userId) async {
    if (shouldThrow) throw SyncException(errorMessage);
    return itemInstanceData;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchEnrichments({DateTime? since}) async {
    if (shouldThrow) throw SyncException(errorMessage);
    return enrichmentData;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('hydrateFromSupabase', () {
    late AppDatabase db;
    late ProfileRepository profileRepo;
    late CellProgressRepository cellProgressRepo;
    late ItemInstanceRepository itemRepo;
    late EnrichmentRepository enrichmentRepo;
    late _MockSupabasePersistence mockPersistence;

    setUp(() {
      db = _makeDb();
      profileRepo = ProfileRepository(db);
      cellProgressRepo = CellProgressRepository(db);
      itemRepo = ItemInstanceRepository(db);
      enrichmentRepo = EnrichmentRepository(db);
      mockPersistence = _MockSupabasePersistence();
    });

    tearDown(() async {
      await db.close();
    });

    test('null persistence is a no-op — no crash, no writes', () async {
      // Seed a profile so we can verify it's untouched.
      await profileRepo.create(
        userId: _userId,
        displayName: 'Local Only',
        currentStreak: 99,
        longestStreak: 99,
      );

      await hydrateFromSupabase(
        userId: _userId,
        persistence: null,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      // Existing local data should be untouched.
      final profile = await profileRepo.read(_userId);
      expect(profile, isNotNull);
      expect(profile!.currentStreak, equals(99));
    });

    test('hydrates profile from Supabase into SQLite', () async {
      mockPersistence.profileData = {
        'id': _userId,
        'display_name': 'Cloud Explorer',
        'current_streak': 7,
        'longest_streak': 15,
        'total_distance_km': 42.5,
        'current_season': 'winter',
      };

      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      final profile = await profileRepo.read(_userId);
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Cloud Explorer'));
      expect(profile.currentStreak, equals(7));
      expect(profile.longestStreak, equals(15));
      expect(profile.totalDistanceKm, equals(42.5));
      expect(profile.currentSeason, equals('winter'));
    });

    test('hydrates cell progress from Supabase into SQLite', () async {
      mockPersistence.cellProgressData = [
        {
          'id': '${_userId}_cell-1',
          'cell_id': 'cell-1',
          'fog_state': 'observed',
          'visit_count': 5,
          'distance_walked': 120.5,
          'restoration_level': 0.67,
          'last_visited': '2026-03-07T10:00:00Z',
        },
        {
          'id': '${_userId}_cell-2',
          'cell_id': 'cell-2',
          'fog_state': 'hidden',
          'visit_count': 1,
          'distance_walked': 30.0,
          'restoration_level': 0.33,
          'last_visited': '2026-03-06T14:30:00Z',
        },
      ];

      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      final cell1 = await cellProgressRepo.read(_userId, 'cell-1');
      expect(cell1, isNotNull);
      expect(cell1!.fogState, equals('observed'));
      expect(cell1.visitCount, equals(5));
      expect(cell1.distanceWalked, equals(120.5));
      expect(cell1.restorationLevel, equals(0.67));

      final cell2 = await cellProgressRepo.read(_userId, 'cell-2');
      expect(cell2, isNotNull);
      expect(cell2!.fogState, equals('hidden'));
      expect(cell2.visitCount, equals(1));
    });

    test('hydrates item instances from Supabase into SQLite', () async {
      mockPersistence.itemInstanceData = [
        {
          'id': 'item-001',
          'definition_id': 'fauna_vulpes_vulpes',
          'affixes':
              '[{"id":"brawn","type":"intrinsic","values":{"brawn":35}}]',
          'acquired_at': '2026-03-05T09:00:00Z',
          'acquired_in_cell_id': 'cell-1',
          'daily_seed': 'seed-20260305',
          'status': 'active',
        },
        {
          'id': 'item-002',
          'definition_id': 'fauna_panthera_leo',
          'affixes': '[]',
          'acquired_at': '2026-03-06T12:00:00Z',
          'acquired_in_cell_id': 'cell-2',
          'daily_seed': 'seed-20260306',
          'status': 'active',
        },
      ];

      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      final items = await itemRepo.getItemsByUser(_userId);
      expect(items.length, equals(2));

      final fox = items.firstWhere((i) => i.id == 'item-001');
      expect(fox.definitionId, equals('fauna_vulpes_vulpes'));
      expect(fox.affixes, hasLength(1));
      expect(fox.affixes.first.id, equals('brawn'));
      expect(fox.acquiredInCellId, equals('cell-1'));
      expect(fox.dailySeed, equals('seed-20260305'));

      final lion = items.firstWhere((i) => i.id == 'item-002');
      expect(lion.definitionId, equals('fauna_panthera_leo'));
      expect(lion.affixes, isEmpty);
    });

    test('hydrates enrichments from Supabase into SQLite', () async {
      mockPersistence.enrichmentData = [
        {
          'definition_id': 'fauna_vulpes_vulpes',
          'animal_class': 'carnivore',
          'food_preference': 'critter',
          'climate': 'temperate',
          'brawn': 25,
          'wit': 35,
          'speed': 30,
          'art_url': null,
          'enriched_at': '2026-03-01T00:00:00Z',
        },
      ];

      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      final enrichment =
          await enrichmentRepo.getEnrichment('fauna_vulpes_vulpes');
      expect(enrichment, isNotNull);
      expect(enrichment!.animalClass, equals(AnimalClass.carnivore));
      expect(enrichment.foodPreference, equals(FoodType.critter));
      expect(enrichment.climate, equals(Climate.temperate));
      expect(enrichment.brawn, equals(25));
      expect(enrichment.wit, equals(35));
      expect(enrichment.speed, equals(30));
    });

    test('hydrates all data types in parallel', () async {
      mockPersistence
        ..profileData = {
          'id': _userId,
          'display_name': 'Full Sync User',
          'current_streak': 3,
          'longest_streak': 10,
          'total_distance_km': 25.0,
          'current_season': 'summer',
        }
        ..cellProgressData = [
          {
            'id': '${_userId}_cell-A',
            'cell_id': 'cell-A',
            'fog_state': 'observed',
            'visit_count': 2,
            'distance_walked': 50.0,
            'restoration_level': 1.0,
          },
        ]
        ..itemInstanceData = [
          {
            'id': 'item-full-1',
            'definition_id': 'fauna_ursus_arctos',
            'affixes': '[]',
            'acquired_at': '2026-03-07T08:00:00Z',
            'acquired_in_cell_id': 'cell-A',
            'status': 'active',
          },
        ]
        ..enrichmentData = [
          {
            'definition_id': 'fauna_ursus_arctos',
            'animal_class': 'carnivore',
            'food_preference': 'fish',
            'climate': 'boreal',
            'brawn': 45,
            'wit': 20,
            'speed': 25,
            'enriched_at': '2026-03-02T00:00:00Z',
          },
        ];

      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      // Profile
      final profile = await profileRepo.read(_userId);
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Full Sync User'));
      expect(profile.currentStreak, equals(3));

      // Cell progress
      final cell = await cellProgressRepo.read(_userId, 'cell-A');
      expect(cell, isNotNull);
      expect(cell!.fogState, equals('observed'));

      // Item
      final items = await itemRepo.getItemsByUser(_userId);
      expect(items.length, equals(1));
      expect(items.first.definitionId, equals('fauna_ursus_arctos'));

      // Enrichment
      final enrichment =
          await enrichmentRepo.getEnrichment('fauna_ursus_arctos');
      expect(enrichment, isNotNull);
      expect(enrichment!.brawn, equals(45));
    });

    test('network error does not crash — graceful fallback', () async {
      mockPersistence.shouldThrow = true;
      mockPersistence.errorMessage = 'connection timeout';

      // Should not throw.
      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      // Nothing written to SQLite.
      final profile = await profileRepo.read(_userId);
      expect(profile, isNull);
      final cells = await cellProgressRepo.readByUser(_userId);
      expect(cells, isEmpty);
      final items = await itemRepo.getItemsByUser(_userId);
      expect(items, isEmpty);
    });

    test('empty server data is a no-op (fresh account)', () async {
      // All defaults (null profile, empty lists).
      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      final profile = await profileRepo.read(_userId);
      expect(profile, isNull);
      final cells = await cellProgressRepo.readByUser(_userId);
      expect(cells, isEmpty);
      final items = await itemRepo.getItemsByUser(_userId);
      expect(items, isEmpty);
    });

    test('duplicate items do not crash — existing PKs handled gracefully',
        () async {
      // Pre-seed an item with id 'item-dup'.
      final existing = ItemInstance(
        id: 'item-dup',
        definitionId: 'fauna_vulpes_vulpes',
        affixes: const [],
        acquiredAt: DateTime(2026, 3, 1),
        acquiredInCellId: 'cell-1',
        status: ItemInstanceStatus.active,
      );
      await itemRepo.addItem(existing, _userId);

      // Supabase returns the same item.
      mockPersistence.itemInstanceData = [
        {
          'id': 'item-dup',
          'definition_id': 'fauna_vulpes_vulpes',
          'affixes': '[]',
          'acquired_at': '2026-03-01T00:00:00Z',
          'acquired_in_cell_id': 'cell-1',
          'status': 'active',
        },
      ];

      // Should not throw despite duplicate PK.
      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      // Item still exists — no duplication.
      final items = await itemRepo.getItemsByUser(_userId);
      expect(items.length, equals(1));
      expect(items.first.id, equals('item-dup'));
    });

    test('handles missing optional fields with sensible defaults', () async {
      mockPersistence.profileData = {
        'id': _userId,
        // Missing: display_name, current_streak, longest_streak, etc.
      };
      mockPersistence.cellProgressData = [
        {
          'cell_id': 'cell-sparse',
          // Missing: id, fog_state, visit_count, distance_walked, etc.
        },
      ];
      mockPersistence.itemInstanceData = [
        {
          'id': 'item-sparse',
          'definition_id': 'fauna_unknown',
          // Missing: affixes, acquired_at, acquired_in_cell_id, etc.
        },
      ];
      mockPersistence.enrichmentData = [
        {
          'definition_id': 'fauna_unknown',
          'animal_class': 'carnivore',
          'food_preference': 'critter',
          'climate': 'temperate',
          // Missing: brawn, wit, speed, art_url
        },
      ];

      // Should not throw — defaults should be applied.
      await hydrateFromSupabase(
        userId: _userId,
        persistence: mockPersistence,
        profileRepo: profileRepo,
        cellProgressRepo: cellProgressRepo,
        itemRepo: itemRepo,
        enrichmentRepo: enrichmentRepo,
      );

      // Verify defaults were applied.
      final profile = await profileRepo.read(_userId);
      expect(profile, isNotNull);
      expect(profile!.displayName, equals('Explorer'));
      expect(profile.currentStreak, equals(0));

      final cell = await cellProgressRepo.read(_userId, 'cell-sparse');
      expect(cell, isNotNull);
      expect(cell!.fogState, equals('observed')); // Default fog state

      final items = await itemRepo.getItemsByUser(_userId);
      expect(items.length, equals(1));
      expect(items.first.affixes, isEmpty); // Default: empty

      final enrichment = await enrichmentRepo.getEnrichment('fauna_unknown');
      expect(enrichment, isNotNull);
      expect(enrichment!.brawn, equals(30)); // Default
      expect(enrichment.wit, equals(30)); // Default
      expect(enrichment.speed, equals(30)); // Default
    });
  });
}
