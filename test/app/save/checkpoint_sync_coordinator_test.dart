import 'dart:async';

import 'package:earth_nova/app/save/application/checkpoint_sync_coordinator.dart';
import 'package:earth_nova/app/save/data/sembast_local_save_store.dart';
import 'package:earth_nova/app/save/domain/checkpoint_gateway.dart';
import 'package:earth_nova/app/save/domain/player_save.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  late SembastLocalSaveStore store;
  late _Gateway gateway;
  late CheckpointSyncCoordinator sync;

  setUp(() {
    store = SembastLocalSaveStore(databaseFactoryMemory.openDatabase('save'));
    gateway = _Gateway();
    sync = CheckpointSyncCoordinator(store: store, gateway: gateway);
  });

  test(
    'response loss retries the same checkpoint without duplicate revision',
    () async {
      final save = _save('one');
      await sync.persist(save);
      gateway.error = StateError('response lost');
      await expectLater(sync.synchronize(), throwsStateError);
      expect(sync.head!.checkpointId, 'one');

      gateway.error = null;
      gateway.result = const CheckpointAccepted(
        checkpointId: 'one',
        revision: 8,
        reconciliationCursor: 3,
      );
      await sync.synchronize();
      expect(sync.head!.ancestorRevision, 8);
    },
  );

  test(
    'confirmation of an older upload never overwrites newer local work',
    () async {
      await sync.persist(_save('old'));
      final response = Completer<CheckpointResult>();
      gateway.pending = response;
      final upload = sync.synchronize();
      await sync.persist(_save('new'));
      response.complete(
        const CheckpointAccepted(
          checkpointId: 'old',
          revision: 2,
          reconciliationCursor: 0,
        ),
      );
      await upload;
      expect(sync.head!.checkpointId, 'new');
      expect(sync.head!.ancestorRevision, isNull);
    },
  );

  test(
    'whole-save cloud selection preserves and replaces the local branch',
    () async {
      await sync.persist(_save('local'));
      gateway.result = CheckpointConflict(
        reason: 'stale_ancestor',
        cloud: PublishedPlayerSave(revision: 3, save: _save('cloud')),
      );
      await sync.synchronize();
      expect(sync.status.phase, SaveSyncPhase.conflict);
      await sync.selectCloudBranch();
      expect(sync.head!.checkpointId, 'cloud');
    },
  );

  test(
    'replayed shared delivery is idempotent after save restoration',
    () async {
      await sync.persist(_save('one'));
      gateway.deliveries = const [
        SharedInteractionDelivery(
          interactionId: 'interaction-1',
          sequence: 4,
          rulesVersion: 'rules-1',
          effect: {'kind': 'obligation_completed'},
        ),
      ];
      await sync.reconcile();
      await sync.reconcile();
      expect(sync.head!.appliedInteractionIds, ['interaction-1']);
      expect(
        (sync.head!.payload['sharedInteractionEffects']! as List),
        hasLength(1),
      );
    },
  );
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

final class _Gateway implements CheckpointGateway {
  CheckpointResult result = const CheckpointAccepted(
    checkpointId: 'one',
    revision: 1,
    reconciliationCursor: 0,
  );
  Object? error;
  Completer<CheckpointResult>? pending;
  List<SharedInteractionDelivery> deliveries = const [];

  @override
  Future<CheckpointResult> submit(PlayerSave save) async {
    if (error != null) throw error!;
    return pending?.future ?? result;
  }

  @override
  Future<PublishedPlayerSave?> fetchLatest() async => null;
  @override
  Future<List<SharedInteractionDelivery>> fetchInteractions({
    required int afterCursor,
  }) async => deliveries.where((item) => item.sequence > afterCursor).toList();
}
