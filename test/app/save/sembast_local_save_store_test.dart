import 'package:earth_nova/app/save/data/sembast_local_save_store.dart';
import 'package:earth_nova/app/save/domain/local_save_store.dart';
import 'package:earth_nova/app/save/domain/player_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  test('corrupt primary restores the prior transactional backup', () async {
    final database = await databaseFactoryMemory.openDatabase('corruption');
    final store = SembastLocalSaveStore(Future.value(database));
    await store.replace(_save('first'));
    await store.replace(_save('second'));
    await StoreRef<String, String>(
      'player_saves',
    ).record('local.player-1.primary').put(database, '{corrupt');

    final restored = await store.restore(
      environment: 'local',
      playerId: 'player-1',
    );
    expect(restored!.source, LocalSaveSource.backup);
    expect(restored.save.checkpointId, 'first');
  });
}

PlayerSave _save(String id) => PlayerSave(
  checkpointId: id,
  playerId: 'player-1',
  environment: 'local',
  ancestorRevision: null,
  rulesVersion: 'rules-1',
  contentVersion: 'content-1',
  createdAt: DateTime.utc(2026, 9, 7),
  updatedAt: DateTime.utc(2026, 9, 7),
  payload: const {
    'profile': <String, Object?>{},
    'pack': <Object?>[],
    'itemKnowledge': <Object?>[],
    'disciplineProgress': <Object?>[],
    'map': <String, Object?>{},
    'encounters': <Object?>[],
    'home': <String, Object?>{},
    'town': <String, Object?>{},
  },
);
