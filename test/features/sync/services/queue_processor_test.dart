import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/models/write_queue_entry.dart';
import 'package:earth_nova/core/persistence/item_instance_repository.dart';
import 'package:earth_nova/core/persistence/write_queue_repository.dart';
import 'package:earth_nova/features/sync/services/queue_processor.dart';
import 'package:earth_nova/features/sync/services/supabase_persistence.dart';
import 'package:earth_nova/shared/constants.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/persistence/test_helpers.dart';

// ---------------------------------------------------------------------------
// Mock: WriteQueueRepository (in-memory list, no DB I/O)
// ---------------------------------------------------------------------------

/// Extends WriteQueueRepository to override all methods with in-memory storage.
/// The [AppDatabase] passed to super is never queried by overridden methods.
class _MockWriteQueueRepository extends WriteQueueRepository {
  final List<WriteQueueEntry> _entries = [];
  int _nextId = 1;

  _MockWriteQueueRepository(AppDatabase db) : super(db);

  // Seed helpers ─────────────────────────────────────────────────────────────

  void seed(List<WriteQueueEntry> entries) {
    _entries
      ..clear()
      ..addAll(entries);
  }

  void addEntry(WriteQueueEntry entry) {
    _entries.add(entry.copyWith(id: _nextId++));
  }

  List<WriteQueueEntry> get allEntries => List.unmodifiable(_entries);

  WriteQueueEntry? findById(int id) =>
      _entries.cast<WriteQueueEntry?>().firstWhere(
            (e) => e!.id == id,
            orElse: () => null,
          );

  // WriteQueueRepository overrides ───────────────────────────────────────────

  @override
  Future<int> enqueue({
    required WriteQueueEntityType entityType,
    required String entityId,
    required WriteQueueOperation operation,
    required String payload,
    required String userId,
  }) async {
    final id = _nextId++;
    _entries.add(WriteQueueEntry(
      id: id,
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      userId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
    return id;
  }

  @override
  Future<List<WriteQueueEntry>> getPending({int? limit, String? userId}) async {
    var pending = _entries
        .where((e) => e.status == WriteQueueStatus.pending)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (userId != null) {
      pending = pending.where((e) => e.userId == userId).toList();
    }
    return limit != null ? pending.take(limit).toList() : pending;
  }

  @override
  Future<List<WriteQueueEntry>> getRejected({String? userId}) async {
    var rejected =
        _entries.where((e) => e.status == WriteQueueStatus.rejected).toList();
    if (userId != null) {
      rejected = rejected.where((e) => e.userId == userId).toList();
    }
    return rejected;
  }

  @override
  Future<int> countPending({String? userId}) async {
    var pending = _entries.where((e) => e.status == WriteQueueStatus.pending);
    if (userId != null) {
      pending = pending.where((e) => e.userId == userId);
    }
    return pending.length;
  }

  @override
  Future<void> deleteEntry(int id) async {
    _entries.removeWhere((e) => e.id == id);
  }

  @override
  Future<void> markRejected(int id, String error) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _entries[idx] = _entries[idx].copyWith(
        status: WriteQueueStatus.rejected,
        lastError: error,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> incrementAttempts(int id, String error) async {
    final idx = _entries.indexWhere((e) => e.id == id);
    if (idx >= 0) {
      _entries[idx] = _entries[idx].copyWith(
        attempts: _entries[idx].attempts + 1,
        lastError: error,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<int> deleteStale(DateTime cutoff) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.createdAt.isBefore(cutoff));
    return before - _entries.length;
  }

  @override
  Future<int> deleteEntries(List<int> ids) async {
    final before = _entries.length;
    _entries.removeWhere((e) => ids.contains(e.id));
    return before - _entries.length;
  }

  @override
  Future<int> clearUser(String userId) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.userId == userId);
    return before - _entries.length;
  }
}

// ---------------------------------------------------------------------------
// Mock: SupabasePersistence (overrides all methods, no real HTTP calls)
// ---------------------------------------------------------------------------

class _MockSupabasePersistence extends SupabasePersistence {
  // Instantiate with a fake SupabaseClient — constructor only stores config,
  // no network calls are made until methods are invoked.
  _MockSupabasePersistence()
      : super(SupabaseClient('http://localhost:54321', 'fake-anon-key'));

  // ── Configuration ─────────────────────────────────────────────────────────

  /// When true, method calls throw [SyncException].
  bool shouldThrowSyncException = false;

  /// When true, item instance operations throw [SyncValidationRejectedException]
  /// from validateEncounter (simulating server validation failure).
  bool shouldRejectValidation = false;

  /// Error message for thrown exceptions.
  String errorMessage = 'test sync error';

  // ── Call tracking ──────────────────────────────────────────────────────────

  int upsertItemInstanceCalls = 0;
  int validateEncounterCalls = 0;
  int upsertCellProgressCalls = 0;
  int upsertProfileCalls = 0;
  int deleteItemInstanceCalls = 0;

  /// Captures the last hasCompletedOnboarding value passed to upsertProfile.
  bool? lastProfileHasCompletedOnboarding;

  void reset() {
    shouldThrowSyncException = false;
    shouldRejectValidation = false;
    shouldReturnFirstGlobal = false;
    errorMessage = 'test sync error';
    upsertItemInstanceCalls = 0;
    validateEncounterCalls = 0;
    upsertCellProgressCalls = 0;
    upsertProfileCalls = 0;
    deleteItemInstanceCalls = 0;
    lastProfileHasCompletedOnboarding = null;
  }

  // ── Overridden methods ────────────────────────────────────────────────────

  @override
  Future<void> upsertItemInstance({
    required String id,
    required String userId,
    required String definitionId,
    required String affixes,
    String? badgesJson,
    String? parentAId,
    String? parentBId,
    required DateTime acquiredAt,
    String? acquiredInCellId,
    String? dailySeed,
    required String status,
    String? displayName,
    String? scientificName,
    String? categoryName,
    String? rarityName,
    String? habitatsJson,
    String? continentsJson,
    String? taxonomicClass,
    String? animalClassName,
    String? animalClassNameEnrichver,
    String? foodPreferenceName,
    String? foodPreferenceNameEnrichver,
    String? climateName,
    String? climateNameEnrichver,
    int? brawn,
    String? brawnEnrichver,
    int? wit,
    String? witEnrichver,
    int? speed,
    String? speedEnrichver,
    String? sizeName,
    String? sizeNameEnrichver,
    String? iconUrlEnrichver,
    String? artUrlEnrichver,
    String? cellHabitatName,
    String? cellHabitatNameEnrichver,
    String? cellClimateName,
    String? cellClimateNameEnrichver,
    String? cellContinentName,
    String? cellContinentNameEnrichver,
    String? locationDistrict,
    String? locationDistrictEnrichver,
    String? locationCity,
    String? locationCityEnrichver,
    String? locationState,
    String? locationStateEnrichver,
    String? locationCountry,
    String? locationCountryEnrichver,
    String? locationCountryCode,
    String? locationCountryCodeEnrichver,
  }) async {
    upsertItemInstanceCalls++;
    if (shouldThrowSyncException) throw SyncException(errorMessage);
    // Note: SyncRejectedException comes from validateEncounter, not here.
  }

  /// When true, validateEncounter reports is_first_global = true.
  bool shouldReturnFirstGlobal = false;

  @override
  Future<EncounterValidationResult> validateEncounter({
    required String itemId,
    required String userId,
    required String definitionId,
    required String cellId,
    String? dailySeed,
    required String acquiredAt,
  }) async {
    validateEncounterCalls++;
    if (shouldRejectValidation) {
      throw SyncValidationRejectedException(errorMessage);
    }
    if (shouldThrowSyncException) throw SyncException(errorMessage);
    return EncounterValidationResult(isFirstGlobal: shouldReturnFirstGlobal);
  }

  @override
  Future<void> upsertCellProgress({
    required String userId,
    required String cellId,
    required String fogState,
    double distanceWalked = 0,
    int visitCount = 0,
    double restorationLevel = 0,
    DateTime? lastVisited,
  }) async {
    upsertCellProgressCalls++;
    if (shouldThrowSyncException) throw SyncException(errorMessage);
    if (shouldRejectValidation) throw SyncRejectedException(errorMessage);
  }

  @override
  Future<void> upsertProfile({
    required String userId,
    String? displayName,
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    String? currentSeason,
    bool? hasCompletedOnboarding,
  }) async {
    upsertProfileCalls++;
    lastProfileHasCompletedOnboarding = hasCompletedOnboarding;
    if (shouldThrowSyncException) throw SyncException(errorMessage);
    if (shouldRejectValidation) throw SyncRejectedException(errorMessage);
  }

  @override
  Future<void> deleteItemInstance({required String id}) async {
    deleteItemInstanceCalls++;
    if (shouldThrowSyncException) throw SyncException(errorMessage);
    if (shouldRejectValidation) throw SyncRejectedException(errorMessage);
  }
}

// ---------------------------------------------------------------------------
// Mock: ItemInstanceRepository (in-memory, no DB I/O)
// ---------------------------------------------------------------------------

class _MockItemInstanceRepository extends ItemInstanceRepository {
  final Map<String, ItemInstance> _items = {};

  _MockItemInstanceRepository(AppDatabase db) : super(db);

  /// Seed an item for getItem() lookups.
  void seedItem(ItemInstance item) {
    _items[item.id] = item;
  }

  /// Read back the current state of a stored item (for assertions).
  ItemInstance? itemById(String id) => _items[id];

  int getItemCalls = 0;
  int updateItemCalls = 0;

  @override
  Future<ItemInstance?> getItem(String id) async {
    getItemCalls++;
    return _items[id];
  }

  @override
  Future<bool> updateItem(ItemInstance instance, String userId) async {
    updateItemCalls++;
    _items[instance.id] = instance;
    return true;
  }
}

// ---------------------------------------------------------------------------
// Factories
// ---------------------------------------------------------------------------

/// Build a [WriteQueueEntry] with sensible defaults.
WriteQueueEntry makeEntry({
  int id = 1,
  WriteQueueEntityType entityType = WriteQueueEntityType.cellProgress,
  String entityId = 'cell-1',
  WriteQueueOperation operation = WriteQueueOperation.upsert,
  String? payload,
  String userId = 'user-1',
  WriteQueueStatus status = WriteQueueStatus.pending,
  int attempts = 0,
  String? lastError,
  DateTime? createdAt,
}) {
  final now = DateTime.now();
  return WriteQueueEntry(
    id: id,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    payload: payload ?? _cellProgressPayload(entityId),
    userId: userId,
    status: status,
    attempts: attempts,
    lastError: lastError,
    createdAt: createdAt ?? now,
    updatedAt: now,
  );
}

/// Build a cell-progress payload JSON for the given cell ID.
String _cellProgressPayload(String cellId) => jsonEncode({
      'cell_id': cellId,
      'fog_state': 'observed',
      'distance_walked': 100.0,
      'visit_count': 1,
      'restoration_level': 0.33,
      'last_visited': '2026-03-07T12:00:00.000Z',
    });

/// Build an item-instance payload JSON.
String _itemInstancePayload(String itemId) => jsonEncode({
      'id': itemId,
      'definition_id': 'fauna_vulpes_vulpes',
      'affixes': '[]',
      'parent_a_id': null,
      'parent_b_id': null,
      'acquired_at': '2026-03-07T12:00:00.000Z',
      'acquired_in_cell_id': 'cell-1',
      'daily_seed': null,
      'status': 'active',
    });

/// Build a profile payload JSON.
String _profilePayload() => jsonEncode({
      'display_name': 'TestPlayer',
      'current_streak': 5,
      'longest_streak': 10,
      'total_distance_km': 15.2,
      'current_season': 'winter',
    });

/// Build a profile payload JSON that includes has_completed_onboarding.
String _profilePayloadWithOnboarding() => jsonEncode({
      'display_name': 'TestPlayer',
      'current_streak': 5,
      'longest_streak': 10,
      'total_distance_km': 15.2,
      'current_season': 'winter',
      'has_completed_onboarding': true,
    });

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  // One shared DB that is passed to mock repo constructors but never queried.
  late AppDatabase sharedDb;
  setUpAll(() {
    sharedDb = createTestDatabase();
  });
  tearDownAll(() => sharedDb.close());

  late _MockWriteQueueRepository mockRepo;
  late _MockSupabasePersistence mockPersistence;
  late _MockItemInstanceRepository mockItemRepo;

  setUp(() {
    mockRepo = _MockWriteQueueRepository(sharedDb);
    mockPersistence = _MockSupabasePersistence();
    mockItemRepo = _MockItemInstanceRepository(sharedDb);
  });

  group('QueueProcessor', () {
    // ── flush with null persistence ──────────────────────────────────────────

    test('flush returns empty summary when persistence is null', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: null,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(id: 1));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(0));
      expect(summary.retried, equals(0));
      expect(summary.rejected, equals(0));
      expect(summary.staleDeleted, equals(0));
      expect(summary.total, equals(0));
      // Queue is unchanged — persistence was skipped.
      expect(mockRepo.allEntries.length, equals(1));
    });

    test('canSync returns false when persistence is null', () {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: null,
        itemRepo: mockItemRepo,
      );
      expect(processor.canSync, isFalse);
    });

    test('canSync returns true when persistence is provided', () {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      expect(processor.canSync, isTrue);
    });

    // ── flush with empty queue ────────────────────────────────────────────────

    test('flush with no pending entries returns empty summary', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      final summary = await processor.flush();

      expect(summary.confirmed, equals(0));
      expect(summary.retried, equals(0));
      expect(summary.rejected, equals(0));
      expect(summary.total, equals(0));
    });

    // ── successful sync ───────────────────────────────────────────────────────

    test('flush confirms cell-progress entry on successful sync', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        payload: _cellProgressPayload('cell-1'),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(summary.retried, equals(0));
      expect(summary.rejected, equals(0));
      expect(mockRepo.allEntries, isEmpty);
      expect(mockPersistence.upsertCellProgressCalls, equals(1));
    });

    test('flush confirms profile entry on successful sync', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: _profilePayload(),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(summary.rejected, equals(0));
      expect(mockRepo.allEntries, isEmpty);
      expect(mockPersistence.upsertProfileCalls, equals(1));
    });

    test('flush confirms item-instance entry on successful sync', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-1',
        payload: _itemInstancePayload('item-uuid-1'),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(summary.rejected, equals(0));
      expect(mockRepo.allEntries, isEmpty);
      expect(mockPersistence.upsertItemInstanceCalls, equals(1));
      expect(mockPersistence.validateEncounterCalls, equals(1));
    });

    test('flush confirms multiple entries and reports correct counts',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo
        ..addEntry(makeEntry(
            id: 1,
            entityType: WriteQueueEntityType.cellProgress,
            entityId: 'cell-1',
            payload: _cellProgressPayload('cell-1')))
        ..addEntry(makeEntry(
            id: 2,
            entityType: WriteQueueEntityType.profile,
            entityId: 'user-1',
            payload: _profilePayload()))
        ..addEntry(makeEntry(
            id: 3,
            entityType: WriteQueueEntityType.cellProgress,
            entityId: 'cell-2',
            payload: _cellProgressPayload('cell-2')));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(3));
      expect(summary.total, equals(3));
      expect(mockRepo.allEntries, isEmpty);
    });

    // ── retry on SyncException ─────────────────────────────────────────────

    test('flush retries entry on SyncException and increments attempts',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        payload: _cellProgressPayload('cell-1'),
        attempts: 0,
      ));
      mockPersistence.shouldThrowSyncException = true;

      final summary = await processor.flush();

      expect(summary.retried, equals(1));
      expect(summary.confirmed, equals(0));
      expect(summary.rejected, equals(0));

      // Entry remains pending with incremented attempts.
      final entry = mockRepo.allEntries.first;
      expect(entry.status, equals(WriteQueueStatus.pending));
      expect(entry.attempts, equals(1));
      expect(entry.lastError, equals('test sync error'));
    });

    test('flush retries multiple times before max retries', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      // Entry with attempts = kWriteQueueMaxRetries - 2 (still has room to retry).
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        payload: _cellProgressPayload('cell-1'),
        attempts: kWriteQueueMaxRetries - 2,
      ));
      mockPersistence.shouldThrowSyncException = true;

      final summary = await processor.flush();

      expect(summary.retried, equals(1));
      expect(summary.rejected, equals(0));
      // Attempts bumped by 1.
      expect(mockRepo.allEntries.first.attempts,
          equals(kWriteQueueMaxRetries - 1));
    });

    // ── reject after max retries ───────────────────────────────────────────

    test('flush rejects entry when max retries exceeded', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      // Entry already at max retries - 1 attempts; next failure triggers rejection.
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        payload: _cellProgressPayload('cell-1'),
        attempts: kWriteQueueMaxRetries - 1,
      ));
      mockPersistence.shouldThrowSyncException = true;
      mockPersistence.errorMessage = 'persistent network error';

      final summary = await processor.flush();

      expect(summary.rejected, equals(1));
      expect(summary.retried, equals(0));
      expect(summary.confirmed, equals(0));

      final entry = mockRepo.allEntries.first;
      expect(entry.status, equals(WriteQueueStatus.rejected));
      expect(entry.lastError,
          contains('Max retries ($kWriteQueueMaxRetries) exceeded'));
    });

    // ── reject immediately on SyncRejectedException ────────────────────────

    test('flush rejects item-instance entry immediately on validation failure',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-1',
        payload: _itemInstancePayload('item-uuid-1'),
        attempts: 0, // No retries used yet.
      ));
      mockPersistence.shouldRejectValidation = true;
      mockPersistence.errorMessage = 'encounter_invalid';

      final summary = await processor.flush();

      expect(summary.rejected, equals(1));
      expect(summary.retried, equals(0));
      expect(summary.confirmed, equals(0));

      final entry = mockRepo.allEntries.first;
      expect(entry.status, equals(WriteQueueStatus.rejected));
      expect(entry.lastError, equals('encounter_invalid'));
    });

    test(
        'flush rejects cell-progress entry immediately on SyncRejectedException',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        payload: _cellProgressPayload('cell-1'),
        attempts: 0,
      ));
      mockPersistence.shouldRejectValidation = true;
      mockPersistence.errorMessage = 'cell_invalid';

      final summary = await processor.flush();

      expect(summary.rejected, equals(1));
      expect(summary.retried, equals(0));

      final entry = mockRepo.allEntries.first;
      expect(entry.status, equals(WriteQueueStatus.rejected));
      expect(entry.lastError, equals('cell_invalid'));
    });

    // ── stale cleanup ──────────────────────────────────────────────────────

    test('flush deletes stale entries before processing pending', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      // Seed a stale entry (older than kWriteQueueStaleAgeHours).
      final staleTime = DateTime.now()
          .subtract(Duration(hours: kWriteQueueStaleAgeHours + 1));
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'stale-cell',
        payload: _cellProgressPayload('stale-cell'),
        createdAt: staleTime,
      ));

      // Also seed a fresh entry.
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'fresh-cell',
        payload: _cellProgressPayload('fresh-cell'),
        createdAt: DateTime.now(),
      ));

      final summary = await processor.flush();

      // Stale entry was deleted before processing.
      expect(summary.staleDeleted, equals(1));
      // Fresh entry was processed and confirmed.
      expect(summary.confirmed, equals(1));
      // Total queue should be empty now.
      expect(mockRepo.allEntries, isEmpty);
    });

    test('flush reports staleDeleted even when no pending entries remain',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      // Only stale entries — nothing fresh to process.
      final staleTime = DateTime.now()
          .subtract(Duration(hours: kWriteQueueStaleAgeHours + 1));
      mockRepo.addEntry(makeEntry(
        createdAt: staleTime,
        entityId: 'stale-only',
        payload: _cellProgressPayload('stale-only'),
      ));

      final summary = await processor.flush();

      expect(summary.staleDeleted, equals(1));
      expect(summary.confirmed, equals(0));
      expect(summary.total, equals(0));
    });

    // ── first discovery badge ────────────────────────────────────────────

    test('flush awards first badge when server returns isFirstGlobal',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      // Seed an item in the mock repo (no badge yet).
      final item = ItemInstance(
        id: 'item-uuid-1',
        definitionId: 'fauna_vulpes_vulpes',
        displayName: 'Test Species',
        category: ItemCategory.fauna,
        affixes: [],
        badges: {},
        acquiredAt: DateTime(2026, 3, 7, 12),
        acquiredInCellId: 'cell-1',
        status: ItemInstanceStatus.active,
      );
      mockItemRepo.seedItem(item);

      // Tell mock persistence to report first global.
      mockPersistence.shouldReturnFirstGlobal = true;

      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-1',
        payload: _itemInstancePayload('item-uuid-1'),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(summary.hasFirstBadges, isTrue);
      expect(summary.firstBadgeItemIds, contains('item-uuid-1'));

      // Item should now have the first discovery badge.
      final updated = mockItemRepo.itemById('item-uuid-1')!;
      expect(updated.isFirstDiscovery, isTrue);
      expect(updated.badges, contains(kBadgeFirstDiscovery));
      expect(mockItemRepo.updateItemCalls, equals(1));
    });

    test('flush does not award badge when server returns isFirstGlobal=false',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      final item = ItemInstance(
        id: 'item-uuid-2',
        definitionId: 'fauna_vulpes_vulpes',
        displayName: 'Test Species',
        category: ItemCategory.fauna,
        affixes: [],
        badges: {},
        acquiredAt: DateTime(2026, 3, 7, 12),
        acquiredInCellId: 'cell-1',
        status: ItemInstanceStatus.active,
      );
      mockItemRepo.seedItem(item);

      // Default: shouldReturnFirstGlobal = false.
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-2',
        payload: _itemInstancePayload('item-uuid-2'),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(summary.hasFirstBadges, isFalse);
      expect(summary.firstBadgeItemIds, isEmpty);

      // Item should NOT have the badge.
      final unchanged = mockItemRepo.itemById('item-uuid-2')!;
      expect(unchanged.isFirstDiscovery, isFalse);
      expect(mockItemRepo.updateItemCalls, equals(0));
    });

    test('flush skips badge if item already has first discovery badge',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      // Item already has the badge.
      final item = ItemInstance(
        id: 'item-uuid-3',
        definitionId: 'fauna_vulpes_vulpes',
        displayName: 'Test Species',
        category: ItemCategory.fauna,
        affixes: [],
        badges: {kBadgeFirstDiscovery},
        acquiredAt: DateTime(2026, 3, 7, 12),
        acquiredInCellId: 'cell-1',
        status: ItemInstanceStatus.active,
      );
      mockItemRepo.seedItem(item);
      mockPersistence.shouldReturnFirstGlobal = true;

      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.itemInstance,
        entityId: 'item-uuid-3',
        payload: _itemInstancePayload('item-uuid-3'),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      // Badge was "awarded" in the sense that server said first,
      // but _awardFirstBadge early-returns without updating.
      expect(mockItemRepo.getItemCalls, equals(1));
      expect(mockItemRepo.updateItemCalls, equals(0));
    });

    // ── backoffDelay ───────────────────────────────────────────────────────

    test('backoffDelay returns exponential values based on attempts', () {
      // Formula: kWriteQueueRetryBaseSeconds * 2^attempts
      expect(QueueProcessor.backoffDelay(0),
          equals(Duration(seconds: kWriteQueueRetryBaseSeconds)));
      expect(QueueProcessor.backoffDelay(1),
          equals(Duration(seconds: kWriteQueueRetryBaseSeconds * 2)));
      expect(QueueProcessor.backoffDelay(2),
          equals(Duration(seconds: kWriteQueueRetryBaseSeconds * 4)));
      expect(QueueProcessor.backoffDelay(3),
          equals(Duration(seconds: kWriteQueueRetryBaseSeconds * 8)));
    });

    test('backoffDelay increases monotonically with attempt count', () {
      final delays = List.generate(6, QueueProcessor.backoffDelay);
      for (var i = 1; i < delays.length; i++) {
        expect(delays[i], greaterThan(delays[i - 1]));
      }
    });

    // ── has_completed_onboarding passthrough ──────────────────────────────

    test('flush profile entry passes has_completed_onboarding to persistence',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: _profilePayloadWithOnboarding(),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(mockPersistence.upsertProfileCalls, equals(1));
      expect(mockPersistence.lastProfileHasCompletedOnboarding, isTrue);
    });

    test(
        'flush profile entry without has_completed_onboarding passes null to persistence',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: _profilePayload(),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(1));
      expect(mockPersistence.upsertProfileCalls, equals(1));
      expect(mockPersistence.lastProfileHasCompletedOnboarding, isNull);
    });

    // ── coalescing ──────────────────────────────────────────────────────────

    test('flush coalesces multiple profile upserts for the same entity',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      // Simulate 3 rapid profile mutations (like startup hydration).
      final now = DateTime.now();
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: jsonEncode({
          'display_name': 'TestPlayer',
          'current_streak': 1,
          'longest_streak': 5,
          'total_distance_km': 0.0,
          'current_season': 'winter',
        }),
        createdAt: now.subtract(const Duration(seconds: 2)),
      ));
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: jsonEncode({
          'display_name': 'TestPlayer',
          'current_streak': 1,
          'longest_streak': 5,
          'total_distance_km': 0.0,
          'current_season': 'winter',
          'has_completed_onboarding': true,
        }),
        createdAt: now.subtract(const Duration(seconds: 1)),
      ));
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: jsonEncode({
          'display_name': 'TestPlayer',
          'current_streak': 1,
          'longest_streak': 5,
          'total_distance_km': 0.0,
          'current_season': 'winter',
          'has_completed_onboarding': true,
          'total_steps': 500,
        }),
        createdAt: now,
      ));

      final summary = await processor.flush();

      // Only the latest payload should be sent.
      expect(summary.confirmed, equals(1));
      expect(mockPersistence.upsertProfileCalls, equals(1));
      // All entries removed from queue.
      expect(mockRepo.allEntries, isEmpty);
    });

    test('flush does not coalesce entries with different entity IDs', () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ));
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-2',
        payload: _cellProgressPayload('cell-2'),
        createdAt: DateTime.now(),
      ));

      final summary = await processor.flush();

      // Both entries processed separately.
      expect(summary.confirmed, equals(2));
      expect(mockPersistence.upsertCellProgressCalls, equals(2));
    });

    test('flush does not coalesce entries with different entity types',
        () async {
      final processor = QueueProcessor(
        queueRepo: mockRepo,
        persistence: mockPersistence,
        itemRepo: mockItemRepo,
      );

      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.profile,
        entityId: 'user-1',
        payload: _profilePayload(),
        createdAt: DateTime.now().subtract(const Duration(seconds: 1)),
      ));
      mockRepo.addEntry(makeEntry(
        entityType: WriteQueueEntityType.cellProgress,
        entityId: 'cell-1',
        createdAt: DateTime.now(),
      ));

      final summary = await processor.flush();

      expect(summary.confirmed, equals(2));
      expect(mockPersistence.upsertProfileCalls, equals(1));
      expect(mockPersistence.upsertCellProgressCalls, equals(1));
    });
  });
}
