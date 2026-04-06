import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/dtos/cell_visit_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

void main() {
  group('CellVisitDto.fromJson → toDomain', () {
    test('round-trip with all fields', () {
      final visitedAt = DateTime.utc(2026, 3, 15, 10, 30);
      final json = {
        'id': 'visit-1',
        'user_id': 'user-abc',
        'cell_id': 'cell-xyz',
        'visited_at': visitedAt.toIso8601String(),
      };

      final dto = CellVisitDto.fromJson(json);
      final visit = dto.toDomain();

      expect(visit.id, 'visit-1');
      expect(visit.userId, 'user-abc');
      expect(visit.cellId, 'cell-xyz');
      expect(visit.visitedAt, visitedAt);
    });

    test('toDomain returns CellVisit instance', () {
      final json = {
        'id': 'visit-2',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'visited_at': DateTime.utc(2026).toIso8601String(),
      };

      final visit = CellVisitDto.fromJson(json).toDomain();
      expect(visit, isA<CellVisit>());
    });

    test('fromDomain round-trip', () {
      final visit = CellVisit(
        id: 'v1',
        cellId: 'c1',
        userId: 'u1',
        visitedAt: DateTime.utc(2026, 1, 1),
      );

      final dto = CellVisitDto.fromDomain(visit);
      expect(dto.id, 'v1');
      expect(dto.cellId, 'c1');
      expect(dto.userId, 'u1');
      expect(dto.visitedAt, DateTime.utc(2026, 1, 1));
    });
  });
}
