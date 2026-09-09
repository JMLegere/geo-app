import 'dart:convert';

import 'package:earth_nova/app/save/domain/player_save.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sealed save detects corruption and enforces account/environment binding',
    () {
      final save = _save().sealed();
      expect(PlayerSave.fromJson(save.toJson()).playerId, 'player-1');

      final corrupt = Map<String, Object?>.from(save.toJson());
      corrupt['payload'] = {'pack': [], 'fabricated': true};
      expect(
        () => PlayerSave.fromJson(corrupt),
        throwsA(isA<PlayerSaveFormatException>()),
      );
    },
  );

  test('rejects duplicate shared-interaction receipts', () {
    final duplicate = _save(applied: const ['one', 'one']);
    final json = duplicate.toJson(includeIntegrity: false);
    json['integrity'] = duplicate.calculateIntegrity();
    expect(
      () => PlayerSave.fromJson(
        Map<String, Object?>.from(jsonDecode(jsonEncode(json)) as Map),
      ),
      throwsA(isA<PlayerSaveFormatException>()),
    );
  });

  test(
    'rejects unsupported schema, wrong environment and oversized storage',
    () {
      final schema = _save().sealed().toJson()..['schemaVersion'] = 99;
      expect(
        () => PlayerSave.fromJson(schema),
        throwsA(isA<PlayerSaveFormatException>()),
      );

      final environment = _save().sealed().toJson()..['environment'] = 'other';
      expect(
        () => PlayerSave.fromJson(environment),
        throwsA(isA<PlayerSaveFormatException>()),
      );

      final oversized = PlayerSave(
        checkpointId: 'large',
        playerId: 'player-1',
        environment: 'local',
        ancestorRevision: null,
        rulesVersion: 'rules-1',
        contentVersion: 'content-1',
        createdAt: DateTime.utc(2026, 9, 7),
        updatedAt: DateTime.utc(2026, 9, 7),
        payload: {
          ..._completePayload,
          'profile': {'blob': 'x' * maximumPlayerSaveBytes},
        },
      );
      expect(
        () => oversized.sealed(),
        throwsA(isA<PlayerSaveFormatException>()),
      );
    },
  );
}

PlayerSave _save({List<String> applied = const []}) => PlayerSave(
  checkpointId: 'checkpoint-1',
  playerId: 'player-1',
  environment: 'local',
  ancestorRevision: null,
  rulesVersion: 'rules-1',
  contentVersion: 'content-1',
  createdAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7),
  payload: _completePayload,
  appliedInteractionIds: applied,
);

const _completePayload = <String, Object?>{
  'profile': <String, Object?>{},
  'pack': <Object?>[],
  'itemKnowledge': <Object?>[],
  'disciplineProgress': <Object?>[],
  'map': <String, Object?>{},
  'encounters': <Object?>[],
  'home': <String, Object?>{},
  'town': <String, Object?>{},
};
