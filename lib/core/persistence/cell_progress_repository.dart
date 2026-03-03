import 'package:drift/drift.dart';
import 'package:fog_of_world/core/database/app_database.dart';
import 'package:fog_of_world/core/models/fog_state.dart';

class CellProgressRepository {
  final AppDatabase _db;

  CellProgressRepository(this._db);

  Future<void> create({
    required String id,
    required String userId,
    required String cellId,
    required FogState fogState,
    double distanceWalked = 0.0,
    int visitCount = 0,
    double restorationLevel = 0.0,
    DateTime? lastVisited,
  }) async {
    final progress = LocalCellProgress(
      id: id,
      userId: userId,
      cellId: cellId,
      fogState: fogState.name,
      distanceWalked: distanceWalked,
      visitCount: visitCount,
      restorationLevel: restorationLevel,
      lastVisited: lastVisited,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.upsertCellProgress(progress);
  }

  Future<LocalCellProgress?> read(String userId, String cellId) async {
    return _db.getCellProgress(userId, cellId);
  }

  Future<List<LocalCellProgress>> readByUser(String userId) async {
    return _db.getCellProgressByUser(userId);
  }

  Future<void> update({
    required String userId,
    required String cellId,
    FogState? fogState,
    double? distanceWalked,
    int? visitCount,
    double? restorationLevel,
    DateTime? lastVisited,
  }) async {
    final existing = await _db.getCellProgress(userId, cellId);
    if (existing == null) {
      throw Exception('Cell progress not found: $userId/$cellId');
    }

    final updated = existing.copyWith(
      fogState: fogState?.name ?? existing.fogState,
      distanceWalked: distanceWalked ?? existing.distanceWalked,
      visitCount: visitCount ?? existing.visitCount,
      restorationLevel: restorationLevel ?? existing.restorationLevel,
      lastVisited: lastVisited != null ? Value(lastVisited) : const Value.absent(),
      updatedAt: DateTime.now(),
    );

    await _db.upsertCellProgress(updated);
  }

  Future<int> delete(String userId, String cellId) async {
    return _db.deleteCellProgress(userId, cellId);
  }

  Future<FogState?> getFogState(String userId, String cellId) async {
    final progress = await _db.getCellProgress(userId, cellId);
    if (progress == null) return null;
    return FogState.fromString(progress.fogState);
  }

  Future<void> updateFogState(
    String userId,
    String cellId,
    FogState newState,
  ) async {
    await update(
      userId: userId,
      cellId: cellId,
      fogState: newState,
    );
  }

  Future<void> addDistance(
    String userId,
    String cellId,
    double distance,
  ) async {
    final existing = await _db.getCellProgress(userId, cellId);
    if (existing == null) {
      throw Exception('Cell progress not found: $userId/$cellId');
    }

    await update(
      userId: userId,
      cellId: cellId,
      distanceWalked: existing.distanceWalked + distance,
    );
  }

  Future<void> incrementVisitCount(String userId, String cellId) async {
    final existing = await _db.getCellProgress(userId, cellId);
    if (existing == null) {
      throw Exception('Cell progress not found: $userId/$cellId');
    }

    await update(
      userId: userId,
      cellId: cellId,
      visitCount: existing.visitCount + 1,
      lastVisited: DateTime.now(),
    );
  }

  Future<List<LocalCellProgress>> getCellsByFogState(
    String userId,
    FogState state,
  ) async {
    final allProgress = await _db.getCellProgressByUser(userId);
    return allProgress
        .where((p) => FogState.fromString(p.fogState) == state)
        .toList();
  }

  Future<Map<FogState, int>> getCellCountByFogState(String userId) async {
    final allProgress = await _db.getCellProgressByUser(userId);
    final counts = <FogState, int>{};
    for (final state in FogState.values) {
      counts[state] = allProgress
          .where((p) => FogState.fromString(p.fogState) == state)
          .length;
    }
    return counts;
  }
}
