import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/models/player_progress.dart';

void main() {
  group('PlayerProgress', () {
    const progress = PlayerProgress(
      userId: 'u_1',
      cellsObserved: 42,
      speciesCollected: 10,
      currentStreak: 3,
      longestStreak: 7,
      totalDistanceKm: 5.5,
    );

    test('constructor stores all fields', () {
      expect(progress.userId, 'u_1');
      expect(progress.cellsObserved, 42);
      expect(progress.speciesCollected, 10);
      expect(progress.currentStreak, 3);
      expect(progress.longestStreak, 7);
      expect(progress.totalDistanceKm, 5.5);
    });

    test('copyWith overrides specified fields', () {
      final updated = progress.copyWith(cellsObserved: 50);
      expect(updated.cellsObserved, 50);
      expect(updated.userId, 'u_1');
      expect(updated.speciesCollected, 10);
    });

    test('toJson and fromJson round-trip', () {
      final json = progress.toJson();
      final restored = PlayerProgress.fromJson(json);
      expect(restored, progress);
    });

    test('equality by all fields', () {
      const a = PlayerProgress(
        userId: 'u_1',
        cellsObserved: 42,
        speciesCollected: 10,
        currentStreak: 3,
        longestStreak: 7,
        totalDistanceKm: 5.5,
      );
      expect(a, progress);
      expect(a.hashCode, progress.hashCode);
    });

    test('not equal when userId differs', () {
      final other = progress.copyWith(userId: 'u_2');
      expect(other == progress, false);
    });

    test('toString contains userId', () {
      expect(progress.toString(), contains('u_1'));
    });
  });
}
