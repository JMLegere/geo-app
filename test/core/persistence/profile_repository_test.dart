import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/persistence/profile_repository.dart';
import 'test_helpers.dart';

void main() {
  group('ProfileRepository', () {
    late ProfileRepository repo;

    setUp(() async {
      final db = createTestDatabase();
      repo = ProfileRepository(db);
    });

    test('create and read player profile', () async {
      const userId = 'user123';
      const displayName = 'TestPlayer';

      // Create
      await repo.create(
        userId: userId,
        displayName: displayName,
        currentStreak: 5,
        longestStreak: 10,
        totalDistanceKm: 25.5,
        currentSeason: 'summer',
      );

      // Read
      final profile = await repo.read(userId);

      expect(profile, isNotNull);
      expect(profile!.id, userId);
      expect(profile.displayName, displayName);
      expect(profile.currentStreak, 5);
      expect(profile.longestStreak, 10);
      expect(profile.totalDistanceKm, 25.5);
      expect(profile.currentSeason, 'summer');
    });

    test('update display name', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'OldName',
      );

      // Update
      await repo.updateDisplayName(userId, 'NewName');

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.displayName, 'NewName');
    });

    test('update current streak', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        currentStreak: 0,
      );

      // Update
      await repo.updateCurrentStreak(userId, 7);

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.currentStreak, 7);
    });

    test('add distance to total', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        totalDistanceKm: 10.0,
      );

      // Add distance
      await repo.addDistance(userId, 5.5);

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.totalDistanceKm, 15.5);
    });

    test('update season', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        currentSeason: 'summer',
      );

      // Update
      await repo.updateSeason(userId, 'winter');

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.currentSeason, 'winter');
    });

    test('increment current streak', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        currentStreak: 5,
        longestStreak: 5,
      );

      // Increment
      await repo.incrementCurrentStreak(userId);

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.currentStreak, 6);
      expect(profile.longestStreak, 6);
    });

    test('reset current streak', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        currentStreak: 10,
        longestStreak: 10,
      );

      // Reset
      await repo.resetCurrentStreak(userId);

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.currentStreak, 0);
      expect(profile.longestStreak, 10);
    });

    test('delete player profile', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
      );

      // Delete
      final deleted = await repo.delete(userId);

      expect(deleted, 1);

      // Verify
      final profile = await repo.read(userId);
      expect(profile, isNull);
    });

    test('profile defaults are correct', () async {
      const userId = 'user123';

      // Create with minimal fields
      await repo.create(
        userId: userId,
        displayName: 'Player',
      );

      // Read
      final profile = await repo.read(userId);

      expect(profile!.currentStreak, 0);
      expect(profile.longestStreak, 0);
      expect(profile.totalDistanceKm, 0.0);
      expect(profile.currentSeason, 'summer');
    });

    test('streak progression works correctly', () async {
      const userId = 'user123';

      // Create
      await repo.create(
        userId: userId,
        displayName: 'Player',
        currentStreak: 0,
        longestStreak: 0,
      );

      // Increment streak 5 times
      for (int i = 0; i < 5; i++) {
        await repo.incrementCurrentStreak(userId);
      }

      // Verify
      final profile = await repo.read(userId);
      expect(profile!.currentStreak, 5);
      expect(profile.longestStreak, 5);

      // Reset and increment again
      await repo.resetCurrentStreak(userId);
      await repo.incrementCurrentStreak(userId);
      await repo.incrementCurrentStreak(userId);

      // Verify
      final profile2 = await repo.read(userId);
      expect(profile2!.currentStreak, 2);
      expect(profile2.longestStreak, 5);
    });

    test('step fields round-trip through SQLite', () async {
      const userId = 'step_user';

      // Create profile with step values
      await repo.create(
        userId: userId,
        displayName: 'StepPlayer',
        totalSteps: 1500,
        lastKnownStepCount: 42000,
      );

      // Read back and assert initial values
      final profile = await repo.read(userId);
      expect(profile, isNotNull);
      expect(profile!.totalSteps, 1500);
      expect(profile.lastKnownStepCount, 42000);

      // Update totalSteps only
      await repo.update(
        userId: userId,
        totalSteps: 2000,
      );

      // Read again and assert updated totalSteps, lastKnownStepCount unchanged
      final updated = await repo.read(userId);
      expect(updated!.totalSteps, 2000);
      expect(updated.lastKnownStepCount, 42000);

      // Update lastKnownStepCount only
      await repo.update(
        userId: userId,
        lastKnownStepCount: 55000,
      );

      // Read again and assert both fields correct
      final updated2 = await repo.read(userId);
      expect(updated2!.totalSteps, 2000);
      expect(updated2.lastKnownStepCount, 55000);
    });

    test('step fields default to zero when not provided', () async {
      const userId = 'default_step_user';

      // Create with no step fields
      await repo.create(
        userId: userId,
        displayName: 'Player',
      );

      final profile = await repo.read(userId);
      expect(profile!.totalSteps, 0);
      expect(profile.lastKnownStepCount, 0);
    });

    test('update preserves step fields when not specified', () async {
      const userId = 'preserve_step_user';

      // Create with step values
      await repo.create(
        userId: userId,
        displayName: 'Player',
        totalSteps: 500,
        lastKnownStepCount: 10000,
      );

      // Update an unrelated field — steps must be preserved
      await repo.update(
        userId: userId,
        currentStreak: 3,
      );

      final profile = await repo.read(userId);
      expect(profile!.totalSteps, 500);
      expect(profile.lastKnownStepCount, 10000);
      expect(profile.currentStreak, 3);
    });
  });
}
