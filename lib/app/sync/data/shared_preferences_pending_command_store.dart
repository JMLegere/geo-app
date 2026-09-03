import 'dart:convert';

import 'package:earth_nova/app/sync/domain/pending_command.dart';
import 'package:earth_nova/app/sync/domain/pending_command_store.dart';
import 'package:earth_nova/core/domain/content/base_item_content.dart';
import 'package:earth_nova/core/domain/content/content_identity.dart';
import 'package:earth_nova/features/identification/domain/entities/identification_entities.dart';
import 'package:earth_nova/features/item_knowledge/domain/entities/item_knowledge_entities.dart';
import 'package:earth_nova/features/living_world/domain/entities/authored_living_world_entities.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _maximumCommands = 100;
const _maximumQueueBytes = 256 * 1024;
const _maximumPayloadBytes = 16 * 1024;
const _maximumRetention = Duration(days: 7);
const _futureClockTolerance = Duration(minutes: 5);

final class SharedPreferencesPendingCommandStore
    implements PendingCommandStore {
  SharedPreferencesPendingCommandStore(this._preferences);

  final SharedPreferences _preferences;

  @override
  Future<List<PendingCommand>> load({
    required String environment,
    required String playerId,
    required DateTime now,
  }) async {
    _validateScope(environment, playerId);
    if (!now.isUtc) throw ArgumentError.value(now, 'now', 'must be UTC');
    final key = _key(environment, playerId);
    final raw = _preferences.getString(key);
    if (raw == null) return const [];

    try {
      if (utf8.encode(raw).length > _maximumQueueBytes) {
        throw const QueueBoundFailure();
      }
      final root = _map(jsonDecode(raw), 'queue');
      _exactKeys(root, const {'version', 'environment', 'playerId', 'commands'});
      if (_integer(root['version'], 'version') !=
              PendingCommand.currentSchemaVersion ||
          _string(root['environment'], 'environment') != environment ||
          _string(root['playerId'], 'playerId') != playerId) {
        throw const FormatException('Queue scope or version mismatch.');
      }
      final rawCommands = _list(root['commands'], 'commands');
      if (rawCommands.length > _maximumCommands) {
        throw const QueueBoundFailure();
      }
      final commands = <PendingCommand>[];
      final ids = <String>{};
      final idempotencyKeys = <String>{};
      for (final rawCommand in rawCommands) {
        final command = _decodeCommand(_map(rawCommand, 'command'));
        if (command.environment != environment || command.playerId != playerId) {
          throw const FormatException('Command scope mismatch.');
        }
        if (!ids.add(command.commandId) ||
            !idempotencyKeys.add(command.idempotencyKey)) {
          throw const FormatException('Duplicate command identity.');
        }
        if (command.enqueuedAt.isAfter(now.add(_futureClockTolerance)) ||
            now.difference(command.enqueuedAt) > _maximumRetention) {
          throw const QueueBoundFailure();
        }
        commands.add(command.recoveredAfterRestart());
      }
      final normalized = List<PendingCommand>.unmodifiable(commands);
      if (_requiresRecoveryWrite(commands, rawCommands)) {
        await _write(environment, playerId, normalized);
      }
      return normalized;
    } on QueueStoreFailure {
      await _removeInvalid(key);
      rethrow;
    } catch (_) {
      await _removeInvalid(key);
      throw const QueueCorruptFailure();
    }
  }

  @override
  Future<void> enqueue(PendingCommand command) async {
    final commands = await load(
      environment: command.environment,
      playerId: command.playerId,
      now: DateTime.now().toUtc(),
    );
    if (commands.any(
      (entry) =>
          entry.commandId == command.commandId ||
          entry.idempotencyKey == command.idempotencyKey,
    )) {
      throw ArgumentError('Pending command identity already exists.');
    }
    await _write(command.environment, command.playerId, [...commands, command]);
  }

  @override
  Future<void> replace(PendingCommand command) async {
    final commands = await load(
      environment: command.environment,
      playerId: command.playerId,
      now: DateTime.now().toUtc(),
    );
    final index = commands.indexWhere(
      (entry) => entry.commandId == command.commandId,
    );
    if (index == -1) throw ArgumentError('Pending command does not exist.');
    final replacement = [...commands]..[index] = command;
    await _write(command.environment, command.playerId, replacement);
  }

  @override
  Future<void> remove(PendingCommand command) async {
    final commands = await load(
      environment: command.environment,
      playerId: command.playerId,
      now: DateTime.now().toUtc(),
    );
    final replacement = commands
        .where((entry) => entry.commandId != command.commandId)
        .toList(growable: false);
    if (replacement.length == commands.length) return;
    await _write(command.environment, command.playerId, replacement);
  }

  @override
  Future<void> purge({
    required String environment,
    required String playerId,
  }) async {
    _validateScope(environment, playerId);
    final suffix =
        '.${Uri.encodeComponent(environment)}.${Uri.encodeComponent(playerId)}';
    final results = await Future.wait(
      _preferences
          .getKeys()
          .where(
            (key) =>
                key.startsWith('pending_commands.v') && key.endsWith(suffix),
          )
          .map(_preferences.remove),
    );
    if (results.any((removed) => !removed)) {
      throw const QueueWriteFailure();
    }
  }

  Future<void> _write(
    String environment,
    String playerId,
    List<PendingCommand> commands,
  ) async {
    if (commands.length > _maximumCommands) throw const QueueBoundFailure();
    final encodedCommands = <Map<String, Object?>>[];
    for (final command in commands) {
      final encoded = _encodeCommand(command);
      final payloadBytes = utf8.encode(jsonEncode(encoded['payload'])).length;
      if (payloadBytes > _maximumPayloadBytes) {
        throw const QueueBoundFailure();
      }
      encodedCommands.add(encoded);
    }
    final raw = jsonEncode({
      'version': PendingCommand.currentSchemaVersion,
      'environment': environment,
      'playerId': playerId,
      'commands': encodedCommands,
    });
    if (utf8.encode(raw).length > _maximumQueueBytes) {
      throw const QueueBoundFailure();
    }
    final key = _key(environment, playerId);
    final previous = _preferences.getString(key);
    final saved = commands.isEmpty
        ? await _preferences.remove(key)
        : await _preferences.setString(key, raw);
    if (saved) return;
    if (previous == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, previous);
    }
    throw const QueueWriteFailure();
  }

  Future<void> _removeInvalid(String key) async {
    if (!await _preferences.remove(key)) throw const QueueWriteFailure();
  }

  String _key(String environment, String playerId) =>
      'pending_commands.v${PendingCommand.currentSchemaVersion}.${Uri.encodeComponent(environment)}.${Uri.encodeComponent(playerId)}';
}

Map<String, Object?> _encodeCommand(PendingCommand command) => {
  'schemaVersion': command.schemaVersion,
  'commandId': command.commandId,
  'idempotencyKey': command.idempotencyKey,
  'kind': command.kind.wireName,
  'payloadVersion': command.payloadVersion,
  'payload': _encodePlan(command.payload.plan),
  'environment': command.environment,
  'playerId': command.playerId,
  'enqueuedAt': command.enqueuedAt.toIso8601String(),
  'attemptCount': command.attemptCount,
  'nextEligibleAttemptAt': command.nextEligibleAttemptAt?.toIso8601String(),
  'lastFailure': command.lastFailure?.name,
  'state': command.state.wireName,
};

PendingCommand _decodeCommand(Map<String, Object?> json) {
  _exactKeys(json, const {
    'schemaVersion',
    'commandId',
    'idempotencyKey',
    'kind',
    'payloadVersion',
    'payload',
    'environment',
    'playerId',
    'enqueuedAt',
    'attemptCount',
    'nextEligibleAttemptAt',
    'lastFailure',
    'state',
  });
  final kind = PendingCommandKind.parse(_string(json['kind'], 'kind'));
  if (kind != PendingCommandKind.identifyItem) {
    throw const FormatException('Unsupported command payload.');
  }
  final lastFailure = switch (json['lastFailure']) {
    null => null,
    String value => SyncFailureKind.values.firstWhere(
      (entry) => entry.name == value,
      orElse: () => throw const FormatException('Unknown failure kind.'),
    ),
    _ => throw const FormatException('Invalid failure kind.'),
  };
  return PendingCommand(
    schemaVersion: _integer(json['schemaVersion'], 'schemaVersion'),
    commandId: _string(json['commandId'], 'commandId'),
    idempotencyKey: _string(json['idempotencyKey'], 'idempotencyKey'),
    kind: kind,
    payloadVersion: _integer(json['payloadVersion'], 'payloadVersion'),
    payload: IdentificationCommandPayload(
      plan: _decodePlan(_map(json['payload'], 'payload')),
    ),
    environment: _string(json['environment'], 'environment'),
    playerId: _string(json['playerId'], 'playerId'),
    enqueuedAt: _utcDate(json['enqueuedAt'], 'enqueuedAt'),
    attemptCount: _integer(json['attemptCount'], 'attemptCount'),
    nextEligibleAttemptAt: json['nextEligibleAttemptAt'] == null
        ? null
        : _utcDate(json['nextEligibleAttemptAt'], 'nextEligibleAttemptAt'),
    lastFailure: lastFailure,
    state: PendingCommandState.parse(_string(json['state'], 'state')),
  );
}

Map<String, Object?> _encodePlan(ItemIdentificationPlan plan) => {
  'item': {
    'id': plan.item.id.value,
    'playerId': plan.item.playerId,
    'baseItemId': plan.item.baseItemId.value,
    'baseItemVersionId': plan.item.baseItemVersion.versionId.value,
    'baseItemRevision': plan.item.baseItemVersion.revision,
  },
  'service': {
    'villagerId': plan.serviceAccess.villagerId.value,
    'villagerDisplayName': plan.serviceAccess.villagerDisplayName,
    'serviceId': plan.serviceAccess.serviceId.value,
    'serviceVersionId': plan.serviceAccess.serviceVersion.versionId.value,
    'serviceRevision': plan.serviceAccess.serviceVersion.revision,
    'serviceDisplayName': plan.serviceAccess.serviceDisplayName,
  },
  'properties': [
    for (final resolution in plan.propertyResolutions)
      {
        'ordinal': resolution.ordinal,
        'definitionId': resolution.definition.id.value,
        'selectorId': resolution.definition.selectorId.value,
        'candidateId': resolution.selectorCandidateId.value,
        'resultKind': switch (resolution.resolution) {
          SelectedPropertyValue() => 'value',
          NoPropertyValue() => 'none',
        },
        'valueId': switch (resolution.resolution) {
          SelectedPropertyValue(:final valueId) => valueId,
          NoPropertyValue() => null,
        },
      },
  ],
};

ItemIdentificationPlan _decodePlan(Map<String, Object?> json) {
  _exactKeys(json, const {'item', 'service', 'properties'});
  final itemJson = _map(json['item'], 'item');
  _exactKeys(itemJson, const {
    'id',
    'playerId',
    'baseItemId',
    'baseItemVersionId',
    'baseItemRevision',
  });
  final baseItemId = StableContentId<BaseItemContent>(
    _string(itemJson['baseItemId'], 'baseItemId'),
  );
  final baseItemVersion = ExactVersionRef<BaseItemContent>(
    stableId: baseItemId,
    versionId: ContentVersionId<BaseItemContent>(
      _string(itemJson['baseItemVersionId'], 'baseItemVersionId'),
    ),
    revision: _integer(itemJson['baseItemRevision'], 'baseItemRevision'),
  );
  final item = ItemKnowledgeItemRef(
    id: ItemKnowledgeItemId(_string(itemJson['id'], 'item.id')),
    playerId: _string(itemJson['playerId'], 'item.playerId'),
    baseItemId: baseItemId,
    baseItemVersion: baseItemVersion,
  );

  final serviceJson = _map(json['service'], 'service');
  _exactKeys(serviceJson, const {
    'villagerId',
    'villagerDisplayName',
    'serviceId',
    'serviceVersionId',
    'serviceRevision',
    'serviceDisplayName',
  });
  final serviceId = ServiceId(_string(serviceJson['serviceId'], 'serviceId'));
  final service = IdentificationServiceAccess(
    villagerId: VillagerId(
      _string(serviceJson['villagerId'], 'villagerId'),
    ),
    villagerDisplayName: _string(
      serviceJson['villagerDisplayName'],
      'villagerDisplayName',
    ),
    serviceId: serviceId,
    serviceVersion: ExactVersionRef<ServiceContent>(
      stableId: StableContentId<ServiceContent>(serviceId.value),
      versionId: ContentVersionId<ServiceContent>(
        _string(serviceJson['serviceVersionId'], 'serviceVersionId'),
      ),
      revision: _integer(serviceJson['serviceRevision'], 'serviceRevision'),
    ),
    serviceDisplayName: _string(
      serviceJson['serviceDisplayName'],
      'serviceDisplayName',
    ),
  );

  final resolutions = <PlannedPropertyResolution>[];
  for (final rawResolution in _list(json['properties'], 'properties')) {
    final resolutionJson = _map(rawResolution, 'property');
    _exactKeys(resolutionJson, const {
      'ordinal',
      'definitionId',
      'selectorId',
      'candidateId',
      'resultKind',
      'valueId',
    });
    final result = switch (_string(resolutionJson['resultKind'], 'resultKind')) {
      'value' => SelectedPropertyValue(
        _string(resolutionJson['valueId'], 'valueId'),
      ),
      'none' when resolutionJson['valueId'] == null => const NoPropertyValue(),
      _ => throw const FormatException('Invalid Property Value result.'),
    };
    resolutions.add(
      PlannedPropertyResolution(
        ordinal: _integer(resolutionJson['ordinal'], 'ordinal'),
        definition: VariablePropertyDefinition(
          id: VariablePropertyDefinitionId(
            _string(resolutionJson['definitionId'], 'definitionId'),
          ),
          baseItemId: baseItemId,
          baseItemVersion: baseItemVersion,
          selectorId: PropertySelectorId(
            _string(resolutionJson['selectorId'], 'selectorId'),
          ),
        ),
        selectorCandidateId: PropertySelectorCandidateId(
          _string(resolutionJson['candidateId'], 'candidateId'),
        ),
        resolution: result,
      ),
    );
  }
  return ItemIdentificationPlan(
    item: item,
    serviceAccess: service,
    propertyResolutions: resolutions,
  );
}

bool _requiresRecoveryWrite(
  List<PendingCommand> commands,
  List<Object?> rawCommands,
) {
  for (var index = 0; index < commands.length; index++) {
    final raw = _map(rawCommands[index], 'command');
    if (raw['state'] == PendingCommandState.dispatching.wireName) return true;
  }
  return false;
}

void _validateScope(String environment, String playerId) {
  if (environment != 'local' && environment != 'prod') {
    throw ArgumentError.value(environment, 'environment');
  }
  if (playerId.trim().isEmpty) throw ArgumentError.value(playerId, 'playerId');
}

Map<String, Object?> _map(Object? value, String name) {
  if (value is! Map) throw FormatException('$name must be an object.');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw FormatException('$name has a non-text key.');
    result[entry.key.toString()] = entry.value;
  }
  return result;
}

List<Object?> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be a list.');
  return List<Object?>.from(value);
}

String _string(Object? value, String name) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$name must be nonblank text.');
  }
  return value;
}

int _integer(Object? value, String name) {
  if (value is! int) throw FormatException('$name must be an integer.');
  return value;
}

DateTime _utcDate(Object? value, String name) {
  final text = _string(value, name);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$name must be a UTC timestamp.');
  }
  return parsed;
}

void _exactKeys(Map<String, Object?> value, Set<String> expected) {
  if (value.keys.toSet().length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw const FormatException('Unexpected persisted queue shape.');
  }
}
