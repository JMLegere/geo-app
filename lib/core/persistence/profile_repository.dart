import 'package:drift/drift.dart' show Value;
import 'package:earth_nova/core/database/app_database.dart';

/// Repository for managing player profile
class ProfileRepository {
  final AppDatabase _db;

  ProfileRepository(this._db);

  /// Create a new player profile
  Future<void> create({
    required String userId,
    required String displayName,
    int currentStreak = 0,
    int longestStreak = 0,
    double totalDistanceKm = 0.0,
    String currentSeason = 'summer',
    bool hasCompletedOnboarding = false,
    double? lastLat,
    double? lastLon,
    int totalSteps = 0,
    int lastKnownStepCount = 0,
  }) async {
    final profile = LocalPlayerProfile(
      id: userId,
      displayName: displayName,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      totalDistanceKm: totalDistanceKm,
      currentSeason: currentSeason,
      hasCompletedOnboarding: hasCompletedOnboarding,
      lastLat: lastLat,
      lastLon: lastLon,
      totalSteps: totalSteps,
      lastKnownStepCount: lastKnownStepCount,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.upsertPlayerProfile(profile);
  }

  /// Read a player profile
  Future<LocalPlayerProfile?> read(String userId) async {
    return _db.getPlayerProfile(userId);
  }

  /// Update a player profile
  ///
  /// [lastLat] and [lastLon] use a sentinel wrapper to distinguish "not
  /// provided" from "set to null". Pass the value directly — `null` means
  /// "leave unchanged" (same as other nullable params).
  Future<void> update({
    required String userId,
    String? displayName,
    int? currentStreak,
    int? longestStreak,
    double? totalDistanceKm,
    String? currentSeason,
    bool? hasCompletedOnboarding,
    double? lastLat,
    double? lastLon,
    bool updateLastPosition = false,
  }) async {
    final existing = await _db.getPlayerProfile(userId);
    if (existing == null) {
      throw Exception('Player profile not found: $userId');
    }

    final updated = existing.copyWith(
      displayName: displayName ?? existing.displayName,
      currentStreak: currentStreak ?? existing.currentStreak,
      longestStreak: longestStreak ?? existing.longestStreak,
      totalDistanceKm: totalDistanceKm ?? existing.totalDistanceKm,
      currentSeason: currentSeason ?? existing.currentSeason,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? existing.hasCompletedOnboarding,
      lastLat: updateLastPosition ? Value(lastLat) : Value.absent(),
      lastLon: updateLastPosition ? Value(lastLon) : Value.absent(),
      updatedAt: DateTime.now(),
    );

    await _db.upsertPlayerProfile(updated);
  }

  /// Delete a player profile
  Future<int> delete(String userId) async {
    return _db.deletePlayerProfile(userId);
  }

  /// Update display name
  Future<void> updateDisplayName(String userId, String displayName) async {
    await update(userId: userId, displayName: displayName);
  }

  /// Update current streak
  Future<void> updateCurrentStreak(String userId, int streak) async {
    await update(userId: userId, currentStreak: streak);
  }

  /// Update longest streak
  Future<void> updateLongestStreak(String userId, int streak) async {
    await update(userId: userId, longestStreak: streak);
  }

  /// Add distance to total
  Future<void> addDistance(String userId, double distanceKm) async {
    await _db.transaction(() async {
      final existing = await _db.getPlayerProfile(userId);
      if (existing == null) {
        throw Exception('Player profile not found: $userId');
      }

      await update(
        userId: userId,
        totalDistanceKm: existing.totalDistanceKm + distanceKm,
      );
    });
  }

  /// Update current season
  Future<void> updateSeason(String userId, String season) async {
    await update(userId: userId, currentSeason: season);
  }

  /// Increment current streak
  Future<void> incrementCurrentStreak(String userId) async {
    await _db.transaction(() async {
      final existing = await _db.getPlayerProfile(userId);
      if (existing == null) {
        throw Exception('Player profile not found: $userId');
      }

      final newStreak = existing.currentStreak + 1;
      final newLongest = newStreak > existing.longestStreak
          ? newStreak
          : existing.longestStreak;

      await update(
        userId: userId,
        currentStreak: newStreak,
        longestStreak: newLongest,
      );
    });
  }

  /// Reset current streak
  Future<void> resetCurrentStreak(String userId) async {
    await update(userId: userId, currentStreak: 0);
  }

  /// Mark onboarding as complete
  Future<void> markOnboardingComplete(String userId) async {
    await update(userId: userId, hasCompletedOnboarding: true);
  }

  /// Get all profiles (for debugging/export)
  Future<List<LocalPlayerProfile>> getAllProfiles() async {
    return _db.select(_db.localPlayerProfileTable).get();
  }
}
