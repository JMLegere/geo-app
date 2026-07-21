import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/data/dtos/cell_visit_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell_visit.dart';

void main() {
  group('CellVisitDto.fromJson → toDomain', () {
    test('round-trip with client event identity', () {
      final visitedAt = DateTime.utc(2026, 3, 15, 10, 30);
      final json = {
        'id': 'visit-1',
        'user_id': 'user-abc',
        'cell_id': 'cell-xyz',
        'client_event_id': 'event-123',
        'visited_at': visitedAt.toIso8601String(),
      };

      final dto = CellVisitDto.fromJson(json);
      final visit = dto.toDomain();

      expect(visit.id, 'visit-1');
      expect(visit.userId, 'user-abc');
      expect(visit.cellId, 'cell-xyz');
      expect(visit.clientEventId, 'event-123');
      expect(visit.visitedAt, visitedAt);
    });

    test('accepts null client event identity for legacy rows', () {
      final dto = CellVisitDto.fromJson({
        'id': 'visit-legacy',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'client_event_id': null,
        'visited_at': DateTime.utc(2026).toIso8601String(),
      });

      expect(dto.clientEventId, isNull);
      expect(dto.toDomain().clientEventId, isNull);
      expect(dto.toJson()['client_event_id'], isNull);
    });

    test(
        'rejects present client event identities that are not nonblank strings',
        () {
      final base = <String, Object?>{
        'id': 'visit-1',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'visited_at': DateTime.utc(2026).toIso8601String(),
      };

      expect(
        () => CellVisitDto.fromJson({...base, 'client_event_id': ''}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CellVisitDto.fromJson({...base, 'client_event_id': '   '}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => CellVisitDto.fromJson({...base, 'client_event_id': 42}),
        throwsA(isA<FormatException>()),
      );
    });

    test('toDomain returns CellVisit instance', () {
      final json = {
        'id': 'visit-2',
        'user_id': 'user-1',
        'cell_id': 'cell-1',
        'client_event_id': 'event-2',
        'visited_at': DateTime.utc(2026).toIso8601String(),
      };

      final visit = CellVisitDto.fromJson(json).toDomain();
      expect(visit, isA<CellVisit>());
    });

    test('accepts a typed external row', () {
      final row = <String, Object?>{
        'id': 'visit-typed',
        'user_id': 'user-typed',
        'cell_id': 'cell-typed',
        'client_event_id': 'event-typed',
        'visited_at': DateTime.utc(2026, 7, 20).toIso8601String(),
      };

      final visit = CellVisitDto.fromJson(row).toDomain();

      expect(visit.id, 'visit-typed');
      expect(visit.userId, 'user-typed');
      expect(visit.cellId, 'cell-typed');
      expect(visit.clientEventId, 'event-typed');
    });

    test('rejects missing required fields', () {
      expect(
        () => CellVisitDto.fromJson({
          'id': 'visit-1',
          'user_id': 'user-1',
          'visited_at': DateTime.utc(2026).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects whitespace-only required identifiers', () {
      expect(
        () => CellVisitDto.fromJson({
          'id': '   ',
          'user_id': 'user-1',
          'cell_id': 'cell-1',
          'visited_at': DateTime.utc(2026).toIso8601String(),
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('fromDomain round-trip', () {
      final visit = CellVisit(
        id: 'v1',
        cellId: 'c1',
        userId: 'u1',
        clientEventId: 'event-1',
        visitedAt: DateTime.utc(2026, 1, 1),
      );

      final dto = CellVisitDto.fromDomain(visit);
      expect(dto.id, 'v1');
      expect(dto.cellId, 'c1');
      expect(dto.userId, 'u1');
      expect(dto.clientEventId, 'event-1');
      expect(dto.visitedAt, DateTime.utc(2026, 1, 1));
    });

    test('toJson serialises all fields correctly', () {
      final visitedAt = DateTime.utc(2026, 4, 1, 12, 0);
      final dto = CellVisitDto.fromJson({
        'id': 'visit-99',
        'user_id': 'user-z',
        'cell_id': 'cell-abc',
        'client_event_id': 'event-99',
        'visited_at': visitedAt.toIso8601String(),
      });
      final out = dto.toJson();

      expect(out['id'], 'visit-99');
      expect(out['user_id'], 'user-z');
      expect(out['cell_id'], 'cell-abc');
      expect(out['client_event_id'], 'event-99');
      expect(out['visited_at'], visitedAt.toIso8601String());
    });
  });
}
