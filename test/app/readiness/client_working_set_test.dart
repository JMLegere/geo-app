import 'package:earth_nova/app/readiness/client_working_set.dart';
import 'package:earth_nova/app/save/data/sembast_local_save_store.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late ClientWorkingSetStore store;

  setUp(() {
    store = ClientWorkingSetStore(
      SembastLocalSaveStore(databaseFactoryMemory.openDatabase('working-set')),
    );
  });

  test(
    'round trips the complete local-save Pack and Map projections',
    () async {
      final workingSet = _workingSet();
      expect(await store.save(workingSet), isTrue);

      final restored = await store.load(environment: 'local', userId: 'user-1');

      expect(restored, isNotNull);
      expect(restored!.capturedAt, workingSet.capturedAt);
      expect(restored.map.cells.single.id, 'cell-1');
      expect(restored.map.visitedCellIds, {'cell-1'});
      expect(restored.map.knowledgeByCellId['cell-1']!.category, 'fauna');
      expect(restored.items.single.id, 'item-1');
    },
  );

  test('account and environment bindings prevent cross-save reads', () async {
    await store.save(_workingSet());
    expect(await store.load(environment: 'prod', userId: 'user-1'), isNull);
    expect(await store.load(environment: 'local', userId: 'user-2'), isNull);
  });

  test('purge removes only the signed-out player save', () async {
    await store.save(_workingSet());
    await store.purge(environment: 'local', userId: 'user-1');
    expect(await store.load(environment: 'local', userId: 'user-1'), isNull);
  });
}

ClientWorkingSet _workingSet() => ClientWorkingSet(
  environment: 'local',
  userId: 'user-1',
  capturedAt: DateTime.utc(2026, 9, 7, 12),
  map: MapStateReady(
    cells: const [
      Cell(
        id: 'cell-1',
        habitats: [],
        polygons: [
          [
            [(lat: 1, lng: 2), (lat: 2, lng: 3), (lat: 3, lng: 1)],
          ],
        ],
        districtId: 'district-1',
        cityId: 'city-1',
        stateId: 'state-1',
        countryId: 'country-1',
      ),
    ],
    visitedCellIds: const {'cell-1'},
    location: LocationState(
      lat: 1,
      lng: 2,
      accuracy: 3,
      timestamp: DateTime.utc(2026, 9, 7, 12),
      isConfident: true,
    ),
    knowledgeByCellId: const {
      'cell-1': CellKnowledgeProjection(
        cellId: 'cell-1',
        state: CellKnowledgeState.informed,
        category: 'fauna',
      ),
    },
  ),
  items: [
    Item(
      id: 'item-1',
      definitionId: 'definition-1',
      baseItemId: 'base-item-1',
      baseItemVersionId: '00000000-0000-4000-8000-000000000001',
      displayName: 'River Otter',
      category: ItemCategory.fauna,
      acquiredAt: DateTime.utc(2026, 9, 7),
      status: ItemStatus.active,
    ),
  ],
);
