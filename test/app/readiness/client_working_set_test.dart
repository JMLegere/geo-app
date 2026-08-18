import 'dart:convert';

import 'package:earth_nova/app/readiness/client_working_set.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;
  late ClientWorkingSetStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    store = ClientWorkingSetStore(preferences);
  });

  test('round trips the bounded Map and Pack working set', () async {
    final workingSet = _workingSet();

    expect(await store.save(workingSet), isTrue);
    final restored = await store.load(environment: 'test', userId: 'user-1');

    expect(restored, isNotNull);
    expect(restored!.capturedAt, workingSet.capturedAt);
    expect(restored.map.cells.single.id, 'cell-1');
    expect(restored.map.visitedCellIds, {'cell-1'});
    expect(restored.items.single.id, 'item-1');
  });

  test('rejects and deletes a snapshot for a different environment', () async {
    await store.save(_workingSet());
    final key = _workingSetKey(preferences);
    final snapshot = _snapshot(preferences, key)..['environment'] = 'prod';
    await preferences.setString(key, jsonEncode(snapshot));

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('rejects and deletes a snapshot for a different user', () async {
    await store.save(_workingSet());
    final key = _workingSetKey(preferences);
    final snapshot = _snapshot(preferences, key)..['userId'] = 'user-2';
    await preferences.setString(key, jsonEncode(snapshot));

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('rejects and deletes an unsupported snapshot version', () async {
    await store.save(_workingSet());
    final key = _workingSetKey(preferences);
    final snapshot = _snapshot(preferences, key)..['version'] = 2;
    await preferences.setString(key, jsonEncode(snapshot));

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('rejects and deletes corrupt or incomplete snapshots', () async {
    await store.save(_workingSet());
    final key = _workingSetKey(preferences);
    await preferences.setString(key, '{bad json');

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);

    await store.save(_workingSet());
    final incomplete = _snapshot(preferences, key)..remove('map');
    await preferences.setString(key, jsonEncode(incomplete));

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('rejects and deletes an oversized snapshot', () async {
    await store.save(_workingSet());
    final key = _workingSetKey(preferences);
    await preferences.setString(key, 'x' * 1000001);

    expect(await store.load(environment: 'test', userId: 'user-1'), isNull);
    expect(preferences.getString(key), isNull);
  });

  test('retains the old complete snapshot when a replacement is oversized',
      () async {
    final original = _workingSet();
    expect(await store.save(original), isTrue);
    final oversized = _workingSet(
      itemName: 'x' * 1000001,
    );

    expect(await store.save(oversized), isFalse);
    final restored = await store.load(environment: 'test', userId: 'user-1');

    expect(restored!.items.single.displayName, 'River Otter');
  });

  test('purge removes every snapshot version for one player and environment',
      () async {
    await store.save(_workingSet());
    await preferences.setString(
      'client_working_set.v0.test.user-1',
      'legacy',
    );
    await preferences.setString(
      'client_working_set.v1.test.user-2',
      'other-player',
    );

    await store.purge(environment: 'test', userId: 'user-1');

    expect(
      preferences.getKeys().where((key) => key.endsWith('.test.user-1')),
      isEmpty,
    );
    expect(preferences.getString('client_working_set.v1.test.user-2'),
        'other-player');
  });
}

ClientWorkingSet _workingSet({String itemName = 'River Otter'}) =>
    ClientWorkingSet(
      environment: 'test',
      userId: 'user-1',
      capturedAt: DateTime.utc(2026, 8, 18, 12),
      map: MapStateReady(
        cells: const [
          Cell(
            id: 'cell-1',
            habitats: [],
            polygons: [],
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
          timestamp: DateTime.utc(2026, 8, 18, 12),
          isConfident: true,
        ),
      ),
      items: [
        Item(
          id: 'item-1',
          definitionId: 'definition-1',
          baseItemId: 'base-item-1',
          baseItemVersionId: '00000000-0000-4000-8000-000000000001',
          displayName: itemName,
          category: ItemCategory.fauna,
          acquiredAt: DateTime.utc(2026, 8, 18),
          status: ItemStatus.active,
        ),
      ],
    );

String _workingSetKey(SharedPreferences preferences) => preferences
    .getKeys()
    .singleWhere((key) => key.startsWith('client_working_set.v1.'));

Map<String, dynamic> _snapshot(SharedPreferences preferences, String key) =>
    Map<String, dynamic>.from(jsonDecode(preferences.getString(key)!) as Map);
