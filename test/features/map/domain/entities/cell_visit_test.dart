import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

void main() {
  group('CellVisit', () {
    final now = DateTime(2026, 4, 6, 12, 0, 0);

    test('constructs with required fields', () {
      final visit = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      expect(visit.id, 'visit-1');
      expect(visit.cellId, 'cell-1');
      expect(visit.userId, 'user-1');
      expect(visit.visitedAt, now);
    });

    test('equality', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      expect(a, equals(b));
    });

    test('inequality when id differs', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-2',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when cellId differs', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-1',
        cellId: 'cell-2',
        userId: 'user-1',
        visitedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when userId differs', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-2',
        visitedAt: now,
      );
      expect(a, isNot(equals(b)));
    });

    test('inequality when visitedAt differs', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: DateTime(2026, 4, 7),
      );
      expect(a, isNot(equals(b)));
    });

    test('hashCode is consistent for equal visits', () {
      final a = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      final b = CellVisit(
        id: 'visit-1',
        cellId: 'cell-1',
        userId: 'user-1',
        visitedAt: now,
      );
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
