import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';

void main() {
  group('HierarchyProgressSummary', () {
    const a = HierarchyProgressSummary(
      id: 'district-1',
      name: 'Downtown',
      level: MapLevel.district,
      cellsVisited: 10,
      cellsTotal: 50,
      progressPercent: 20.0,
      rank: 3,
    );

    const b = HierarchyProgressSummary(
      id: 'district-1',
      name: 'Downtown',
      level: MapLevel.district,
      cellsVisited: 10,
      cellsTotal: 50,
      progressPercent: 20.0,
      rank: 3,
    );

    const c = HierarchyProgressSummary(
      id: 'district-2',
      name: 'Uptown',
      level: MapLevel.district,
      cellsVisited: 5,
      cellsTotal: 30,
      progressPercent: 16.6,
      rank: 7,
    );

    test('identical instances are equal', () {
      expect(a, equals(a));
    });

    test('two instances with same fields are equal', () {
      expect(a, equals(b));
    });

    test('non-const instances with same fields are equal (exercises == body)',
        () {
      // Use non-const to avoid Dart const-canonicalization, forcing field comparison.
      final x = HierarchyProgressSummary(
        id: 'district-1',
        name: 'Downtown',
        level: MapLevel.district,
        cellsVisited: 10,
        cellsTotal: 50,
        progressPercent: 20.0,
        rank: 3,
      );
      final y = HierarchyProgressSummary(
        id: 'district-1',
        name: 'Downtown',
        level: MapLevel.district,
        cellsVisited: 10,
        cellsTotal: 50,
        progressPercent: 20.0,
        rank: 3,
      );
      expect(x, equals(y));
      expect(x.hashCode, equals(y.hashCode));
    });

    test('instances with different fields are not equal', () {
      expect(a, isNot(equals(c)));
    });

    test('equal instances have the same hashCode', () {
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different instances have different hashCode', () {
      expect(a.hashCode, isNot(equals(c.hashCode)));
    });

    test('not equal to a non-HierarchyProgressSummary object', () {
      // ignore: unrelated_type_equality_checks
      expect(a == 'district-1', isFalse);
    });
  });
}
