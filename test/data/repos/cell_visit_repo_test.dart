import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/cell_visit_repo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late CellVisitRepo repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CellVisitRepo(db);
  });

  tearDown(() => db.close());

  group('CellVisitRepo', () {
    test('get returns null for unvisited cell', () async {
      final result = await repo.get('user1', 'cell-A');
      expect(result, isNull);
    });

    test('upsert creates new visit record', () async {
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
        visitCount: const Value(1),
      ));
      final result = await repo.get('user1', 'cell-A');
      expect(result, isNotNull);
      expect(result!.visitCount, 1);
    });

    test('upsert updates existing visit record', () async {
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
        visitCount: const Value(1),
      ));
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
        visitCount: const Value(5),
      ));
      final result = await repo.get('user1', 'cell-A');
      expect(result!.visitCount, 5);
    });

    test('getAllVisited returns all visited cells for user', () async {
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
      ));
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-B',
      ));
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user2',
        cellId: 'cell-C',
      ));
      final user1Cells = await repo.getAllVisited('user1');
      expect(user1Cells.length, 2);
      expect(
          user1Cells.map((c) => c.cellId), containsAll(['cell-A', 'cell-B']));
    });

    test('incrementVisit increases visit_count by 1', () async {
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
        visitCount: const Value(3),
      ));
      await repo.incrementVisit('user1', 'cell-A');
      final result = await repo.get('user1', 'cell-A');
      expect(result!.visitCount, 4);
    });

    test('incrementVisit creates record if none exists', () async {
      await repo.incrementVisit('user1', 'cell-new');
      final result = await repo.get('user1', 'cell-new');
      expect(result, isNotNull);
      expect(result!.visitCount, 1);
    });

    test('addDistance adds to distance_walked', () async {
      await repo.upsert(CellVisitsTableCompanion.insert(
        userId: 'user1',
        cellId: 'cell-A',
        distanceWalked: const Value(100.0),
      ));
      await repo.addDistance('user1', 'cell-A', 250.0);
      final result = await repo.get('user1', 'cell-A');
      expect(result!.distanceWalked, closeTo(350.0, 0.001));
    });

    test(
        'composite PK works correctly — different users same cell are independent',
        () async {
      await repo.incrementVisit('user1', 'cell-shared');
      await repo.incrementVisit('user1', 'cell-shared');
      await repo.incrementVisit('user2', 'cell-shared');

      final u1 = await repo.get('user1', 'cell-shared');
      final u2 = await repo.get('user2', 'cell-shared');
      expect(u1!.visitCount, 2);
      expect(u2!.visitCount, 1);
    });
  });
}
