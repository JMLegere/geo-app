import 'package:earth_nova/app/save/data/local_save_database.dart';
import 'package:earth_nova/app/save/data/sembast_local_save_store.dart';
import 'package:earth_nova/app/save/domain/local_save_store.dart';
import 'package:earth_nova/app/save/domain/player_save.dart';
import 'package:earth_nova/core/domain/entities/item.dart';
import 'package:earth_nova/features/identification/data/dtos/item_dto.dart';
import 'package:earth_nova/features/map/data/dtos/cell_dto.dart';
import 'package:earth_nova/features/map/data/dtos/cell_knowledge_projection_dto.dart';
import 'package:earth_nova/features/map/domain/entities/location_state.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/presentation/providers/map_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

final localSaveStoreProvider = Provider<LocalSaveStore>(
  (ref) => SembastLocalSaveStore(openLocalSaveDatabase()),
);
final clientWorkingSetStoreProvider = Provider<ClientWorkingSetStore>(
  (ref) => ClientWorkingSetStore(ref.watch(localSaveStoreProvider)),
);

class ClientWorkingSet {
  const ClientWorkingSet({
    required this.environment,
    required this.userId,
    required this.capturedAt,
    required this.map,
    required this.items,
  });

  final String environment;
  final String userId;
  final DateTime capturedAt;
  final MapStateReady map;
  final List<Item> items;
}

class ClientWorkingSetStore {
  ClientWorkingSetStore(this._store);

  final LocalSaveStore _store;

  Future<ClientWorkingSet?> load({
    required String environment,
    required String userId,
  }) async {
    if (environment.isEmpty || userId.isEmpty) return null;
    try {
      final restored = await _store.restore(
        environment: environment,
        playerId: userId,
      );
      if (restored == null) return null;
      final root = restored.save.payload;
      final capturedAt = _date(root['capturedAt'], 'capturedAt');
      final map = _decodeMap(_map(root['map'], 'map'));
      final items = _list(root['pack'], 'pack')
          .map((item) => ItemDto.fromJson(_map(item, 'item')).toDomain())
          .toList(growable: false);
      return ClientWorkingSet(
        environment: environment,
        userId: userId,
        capturedAt: capturedAt,
        map: map,
        items: items,
      );
    } catch (_) {
      return null;
    }
  }

  Future<bool> save(ClientWorkingSet workingSet) async {
    if (workingSet.environment.isEmpty || workingSet.userId.isEmpty) {
      return false;
    }
    final payload = <String, Object?>{
      'capturedAt': workingSet.capturedAt.toIso8601String(),
      'map': _encodeMap(workingSet.map),
      'pack': [
        for (final item in workingSet.items) ItemDto.fromDomain(item).toJson(),
      ],
      // Complete boundary sections are populated by their projections as the
      // vertical slices evolve; empty means known-empty, never omitted.
      'profile': <String, Object?>{},
      'itemKnowledge': <Object?>[],
      'disciplineProgress': <Object?>[],
      'encounters': <Object?>[],
      'home': <String, Object?>{},
      'town': <String, Object?>{},
    };
    try {
      final current = await _store.restore(
        environment: workingSet.environment,
        playerId: workingSet.userId,
      );
      await _store.replace(
        PlayerSave(
          checkpointId: const Uuid().v4(),
          playerId: workingSet.userId,
          environment: workingSet.environment,
          ancestorRevision: current?.save.ancestorRevision,
          rulesVersion: 'v3',
          contentVersion: 'working-set-v1',
          reconciliationCursor: current?.save.reconciliationCursor ?? 0,
          createdAt: current?.save.createdAt ?? workingSet.capturedAt,
          updatedAt: workingSet.capturedAt,
          payload: payload,
          appliedInteractionIds:
              current?.save.appliedInteractionIds ?? const [],
        ),
      );
      return true;
    } on LocalSaveStorageException {
      return false;
    }
  }

  Future<void> purge({
    required String environment,
    required String userId,
  }) async {
    if (environment.isEmpty || userId.isEmpty) return;
    await _store.purge(environment: environment, playerId: userId);
  }

  MapStateReady _decodeMap(Map<String, dynamic> json) {
    final cells = _list(json['cells'], 'map.cells')
        .map(
          (cell) =>
              CellDto.fromJson(_validatedCell(_map(cell, 'cell'))).toDomain(),
        )
        .toList(growable: false);
    final visitedCellIds = _stringSet(
      json['visitedCellIds'],
      'map.visitedCellIds',
    );
    final locationJson = _map(json['location'], 'map.location');
    final location = LocationState(
      lat: _number(locationJson['lat'], 'map.location.lat'),
      lng: _number(locationJson['lng'], 'map.location.lng'),
      accuracy: _number(locationJson['accuracy'], 'map.location.accuracy'),
      timestamp: _date(locationJson['timestamp'], 'map.location.timestamp'),
      isConfident: _bool(
        locationJson['isConfident'],
        'map.location.isConfident',
      ),
    );
    final knowledge = <String, CellKnowledgeProjection>{};
    for (final entry in _map(
      json['knowledgeByCellId'],
      'map.knowledgeByCellId',
    ).entries) {
      if (entry.key.isEmpty) {
        throw const FormatException('Empty knowledge cell id.');
      }
      final value = _map(entry.value, 'knowledge');
      if (value['cell_id'] != entry.key ||
          value['state'] is! String ||
          (value['category'] != null && value['category'] is! String)) {
        throw const FormatException('Invalid cell knowledge.');
      }
      knowledge[entry.key] = CellKnowledgeProjectionDto.fromJson(
        value,
      ).toDomain();
    }
    return MapStateReady(
      cells: cells,
      visitedCellIds: visitedCellIds,
      location: location,
      knowledgeByCellId: Map.unmodifiable(knowledge),
    );
  }

  Map<String, dynamic> _encodeMap(MapStateReady map) => {
    'cells': [for (final cell in map.cells) CellDto.fromDomain(cell).toJson()],
    'visitedCellIds': map.visitedCellIds.toList(growable: false),
    'location': {
      'lat': map.location.lat,
      'lng': map.location.lng,
      'accuracy': map.location.accuracy,
      'timestamp': map.location.timestamp.toIso8601String(),
      'isConfident': map.location.isConfident,
    },
    'knowledgeByCellId': {
      for (final entry in map.knowledgeByCellId.entries)
        entry.key: CellKnowledgeProjectionDto(
          cellId: entry.value.cellId,
          state: entry.value.state,
          category: entry.value.category,
        ).toJson(),
    },
  };

  Map<String, dynamic> _validatedCell(Map<String, dynamic> cell) {
    const textKeys = [
      'cell_id',
      'district_id',
      'city_id',
      'state_id',
      'country_id',
      'geometry_source_version',
      'geometry_generation_mode',
      'centroid_dataset_version',
      'geometry_contract',
      'habitat_source_version',
      'habitat_confidence',
    ];
    for (final key in textKeys) {
      if (cell[key] is! String) throw FormatException('Invalid cell $key.');
    }
    _stringList(cell['habitats'], 'cell.habitats');
    for (final polygon in _list(cell['polygons'], 'cell.polygons')) {
      for (final ring in _list(polygon, 'cell.ring')) {
        for (final point in _list(ring, 'cell.point')) {
          final pointJson = _map(point, 'cell.point');
          _number(pointJson['lat'], 'cell.point.lat');
          _number(pointJson['lng'], 'cell.point.lng');
        }
      }
    }
    return cell;
  }
}

Map<String, dynamic> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be a list.');
  return value;
}

List<String> _stringList(Object? value, String name) {
  final list = _list(value, name);
  if (list.any((entry) => entry is! String)) {
    throw FormatException('$name must contain strings.');
  }
  return list.cast<String>();
}

Set<String> _stringSet(Object? value, String name) =>
    _stringList(value, name).toSet();

double _number(Object? value, String name) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$name must be a finite number.');
  }
  return value.toDouble();
}

DateTime _date(Object? value, String name) {
  if (value is! String) {
    throw FormatException('$name must be an ISO timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw FormatException('$name must be an ISO timestamp.');
  }
  return parsed;
}

bool _bool(Object? value, String name) {
  if (value is! bool) {
    throw FormatException('$name must be a boolean.');
  }
  return value;
}
