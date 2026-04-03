import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/data/database.dart';
import 'package:earth_nova/data/repos/cell_property_repo.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late CellPropertyRepo repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CellPropertyRepo(db);
  });

  tearDown(() => db.close());

  group('CellPropertyRepo', () {
    test('get returns null for unknown cellId', () async {
      final result = await repo.get('cell-unknown');
      expect(result, isNull);
    });

    test('upsert creates new cell property', () async {
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'cell-1',
        habitatsJson: '["forest"]',
        climate: 'temperate',
        continent: 'europe',
      ));
      final result = await repo.get('cell-1');
      expect(result, isNotNull);
      expect(result!.cellId, 'cell-1');
      expect(result.climate, 'temperate');
      expect(result.continent, 'europe');
    });

    test('upsert updates existing cell property', () async {
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'cell-1',
        habitatsJson: '["forest"]',
        climate: 'temperate',
        continent: 'europe',
      ));
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'cell-1',
        habitatsJson: '["mountain","forest"]',
        climate: 'boreal',
        continent: 'europe',
      ));
      final result = await repo.get('cell-1');
      expect(result!.climate, 'boreal');
      expect(result.habitatsJson, '["mountain","forest"]');
    });

    test('getAll returns all cell properties', () async {
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'cell-1',
        habitatsJson: '["forest"]',
        climate: 'temperate',
        continent: 'europe',
      ));
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'cell-2',
        habitatsJson: '["desert"]',
        climate: 'tropic',
        continent: 'africa',
      ));
      final all = await repo.getAll();
      expect(all.length, 2);
      expect(all.map((c) => c.cellId), containsAll(['cell-1', 'cell-2']));
    });

    test('cell properties are global — no userId scoping', () async {
      // Same cell written once, readable without a user context
      await repo.upsert(CellPropertiesTableCompanion.insert(
        cellId: 'global-cell',
        habitatsJson: '["plains"]',
        climate: 'temperate',
        continent: 'northAmerica',
      ));
      final result = await repo.get('global-cell');
      expect(result, isNotNull);
      // Verify all expected global fields are present
      expect(result!.habitatsJson, '["plains"]');
      expect(result.continent, 'northAmerica');
    });
  });
}
