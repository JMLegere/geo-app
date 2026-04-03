import 'package:drift/drift.dart';
import 'package:earth_nova/data/database.dart';

class PlayerRepo {
  final AppDatabase _db;
  PlayerRepo(this._db);

  Future<Player?> get(String userId) =>
      (_db.select(_db.playersTable)..where((t) => t.id.equals(userId)))
          .getSingleOrNull();

  Future<void> upsert(PlayersTableCompanion entry) =>
      _db.into(_db.playersTable).insertOnConflictUpdate(entry);

  Future<void> incrementCells(String userId) => _db.customStatement(
        'UPDATE players_table SET cells_explored = cells_explored + 1, '
        'updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), userId],
      );

  Future<void> incrementSpecies(String userId) => _db.customStatement(
        'UPDATE players_table SET species_discovered = species_discovered + 1, '
        'updated_at = ? WHERE id = ?',
        [DateTime.now().toIso8601String(), userId],
      );

  Future<void> addDistance(String userId, double km) => _db.customStatement(
        'UPDATE players_table SET total_distance_km = total_distance_km + ?, '
        'updated_at = ? WHERE id = ?',
        [km, DateTime.now().toIso8601String(), userId],
      );

  Future<void> updateStreak(String userId, int current, int longest) =>
      (_db.update(_db.playersTable)..where((t) => t.id.equals(userId))).write(
        PlayersTableCompanion(
          currentStreak: Value(current),
          longestStreak: Value(longest),
          updatedAt: Value(DateTime.now()),
        ),
      );
}
