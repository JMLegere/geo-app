import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/database/app_database.dart';
import 'package:earth_nova/core/models/cell_properties.dart';
import 'package:earth_nova/core/models/climate.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/persistence/cell_property_repository.dart';

AppDatabase _makeDb() => AppDatabase(NativeDatabase.memory());

CellProperties _makeProps(String cellId) => CellProperties(
      cellId: cellId,
      habitats: {Habitat.forest},
      climate: Climate.temperate,
      continent: Continent.europe,
      locationId: null,
      createdAt: DateTime(2026),
    );

void main() {
  setUpAll(() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('CellPropertyRepository', () {
    late CellPropertyRepository repo;

    setUp(() {
      repo = CellPropertyRepository(_makeDb());
    });

    test('upsert and get round-trip', () async {
      final props = _makeProps('cell_1');
      await repo.upsert(props);

      final result = await repo.get('cell_1');

      expect(result, isNotNull);
      expect(result!.cellId, 'cell_1');
      expect(result.climate, Climate.temperate);
      expect(result.continent, Continent.europe);
      expect(result.habitats, {Habitat.forest});
      expect(result.locationId, isNull);
    });

    test('batchUpsert writes all cells in a single transaction', () async {
      final cells = List.generate(10, (i) => _makeProps('cell_$i'));
      await repo.batchUpsert(cells);

      final all = await repo.getAll();
      expect(all.length, 10);
      final ids = all.map((p) => p.cellId).toSet();
      for (var i = 0; i < 10; i++) {
        expect(ids, contains('cell_$i'));
      }
    });

    test('batchUpsert on empty list is a no-op', () async {
      await repo.batchUpsert([]);
      final all = await repo.getAll();
      expect(all, isEmpty);
    });

    test('batchUpsert updates on conflict (upsert semantics)', () async {
      final original = _makeProps('cell_1');
      await repo.upsert(original);

      final updated = original.copyWith(climate: Climate.tropic);
      await repo.batchUpsert([updated]);

      final result = await repo.get('cell_1');
      expect(result!.climate, Climate.tropic);
    });

    test('batchUpsert handles 1500 cells without error', () async {
      final cells = List.generate(1500, (i) => _makeProps('cell_$i'));
      await repo.batchUpsert(cells);

      final count = (await repo.getAll()).length;
      expect(count, 1500);
    });
  });
}
