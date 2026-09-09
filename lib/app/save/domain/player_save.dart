import 'dart:convert';

import 'package:crypto/crypto.dart';

const currentPlayerSaveSchema = 1;
const maximumPlayerSaveBytes = 8 * 1024 * 1024;

/// Complete, player-owned synchronization unit. Server-owned world state,
/// credentials, unpublished content and undiscovered identity are excluded.
final class PlayerSave {
  PlayerSave({
    required this.checkpointId,
    required this.playerId,
    required this.environment,
    required this.ancestorRevision,
    required this.rulesVersion,
    required this.contentVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.payload,
    this.schemaVersion = currentPlayerSaveSchema,
    this.reconciliationCursor = 0,
    this.evidence = const [],
    this.appliedInteractionIds = const [],
    this.integrity,
  });

  final int schemaVersion;
  final String checkpointId;
  final String playerId;
  final String environment;
  final int? ancestorRevision;
  final String rulesVersion;
  final String contentVersion;
  final int reconciliationCursor;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> payload;
  final List<Map<String, Object?>> evidence;
  final List<String> appliedInteractionIds;
  final String? integrity;

  Map<String, Object?> toJson({bool includeIntegrity = true}) => {
    'schemaVersion': schemaVersion,
    'checkpointId': checkpointId,
    'playerId': playerId,
    'environment': environment,
    'ancestorRevision': ancestorRevision,
    'rulesVersion': rulesVersion,
    'contentVersion': contentVersion,
    'reconciliationCursor': reconciliationCursor,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'payload': payload,
    'evidence': evidence,
    'appliedInteractionIds': appliedInteractionIds,
    if (includeIntegrity) 'integrity': integrity ?? calculateIntegrity(),
  };

  String calculateIntegrity() => sha256
      .convert(utf8.encode(jsonEncode(toJson(includeIntegrity: false))))
      .toString();

  PlayerSave sealed() => PlayerSave.fromJson({
    ...toJson(includeIntegrity: false),
    'integrity': calculateIntegrity(),
  });

  static PlayerSave fromJson(Map<String, Object?> json) {
    final schema = _integer(json['schemaVersion'], 'schemaVersion');
    if (schema != currentPlayerSaveSchema) {
      throw PlayerSaveFormatException('Unsupported save schema $schema.');
    }
    final save = PlayerSave(
      schemaVersion: schema,
      checkpointId: _text(json['checkpointId'], 'checkpointId'),
      playerId: _text(json['playerId'], 'playerId'),
      environment: _text(json['environment'], 'environment'),
      ancestorRevision: json['ancestorRevision'] == null
          ? null
          : _integer(json['ancestorRevision'], 'ancestorRevision'),
      rulesVersion: _text(json['rulesVersion'], 'rulesVersion'),
      contentVersion: _text(json['contentVersion'], 'contentVersion'),
      reconciliationCursor: _integer(
        json['reconciliationCursor'],
        'reconciliationCursor',
      ),
      createdAt: _timestamp(json['createdAt'], 'createdAt'),
      updatedAt: _timestamp(json['updatedAt'], 'updatedAt'),
      payload: _map(json['payload'], 'payload'),
      evidence: _mapList(json['evidence'], 'evidence'),
      appliedInteractionIds: _strings(
        json['appliedInteractionIds'],
        'appliedInteractionIds',
      ),
      integrity: _text(json['integrity'], 'integrity'),
    );
    final bytes = utf8.encode(jsonEncode(save.toJson())).length;
    if (bytes > maximumPlayerSaveBytes) {
      throw const PlayerSaveFormatException('Save exceeds the storage limit.');
    }
    if (save.integrity != save.calculateIntegrity()) {
      throw const PlayerSaveFormatException('Save integrity check failed.');
    }
    if (save.environment != 'local' && save.environment != 'prod') {
      throw const PlayerSaveFormatException('Unknown save environment.');
    }
    if (save.reconciliationCursor < 0 ||
        (save.ancestorRevision != null && save.ancestorRevision! < 0)) {
      throw const PlayerSaveFormatException('Negative server ordering value.');
    }
    if (save.appliedInteractionIds.toSet().length !=
        save.appliedInteractionIds.length) {
      throw const PlayerSaveFormatException('Duplicate interaction receipt.');
    }
    const requiredSections = {
      'profile',
      'pack',
      'itemKnowledge',
      'disciplineProgress',
      'map',
      'encounters',
      'home',
      'town',
    };
    if (!save.payload.keys.toSet().containsAll(requiredSections)) {
      throw const PlayerSaveFormatException(
        'Complete save section is missing.',
      );
    }
    const forbidden = {
      'credentials',
      'undiscoveredItems',
      'futureOutcomes',
      'secrets',
    };
    if (save.payload.keys.any(forbidden.contains)) {
      throw const PlayerSaveFormatException(
        'Save contains server-owned or undisclosed information.',
      );
    }
    return save;
  }
}

final class PlayerSaveFormatException implements Exception {
  const PlayerSaveFormatException(this.message);
  final String message;
  @override
  String toString() => 'PlayerSaveFormatException: $message';
}

String _text(Object? value, String field) {
  if (value is! String || value.isEmpty) {
    throw PlayerSaveFormatException('$field must be non-empty text.');
  }
  return value;
}

int _integer(Object? value, String field) {
  if (value is! int) throw PlayerSaveFormatException('$field must be an int.');
  return value;
}

DateTime _timestamp(Object? value, String field) {
  final parsed = value is String ? DateTime.tryParse(value) : null;
  if (parsed == null) throw PlayerSaveFormatException('$field is invalid.');
  return parsed.toUtc();
}

Map<String, Object?> _map(Object? value, String field) {
  if (value is! Map) throw PlayerSaveFormatException('$field must be a map.');
  return Map<String, Object?>.from(value);
}

List<Map<String, Object?>> _mapList(Object? value, String field) {
  if (value is! List) throw PlayerSaveFormatException('$field must be a list.');
  return value.map((entry) => _map(entry, field)).toList(growable: false);
}

List<String> _strings(Object? value, String field) {
  if (value is! List || value.any((entry) => entry is! String)) {
    throw PlayerSaveFormatException('$field must contain text.');
  }
  return value.cast<String>().toList(growable: false);
}
