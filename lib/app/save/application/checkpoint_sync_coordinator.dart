import '../domain/checkpoint_gateway.dart';
import '../domain/local_save_store.dart';
import '../domain/player_save.dart';

enum SaveSyncPhase { saved, syncing, offline, conflict, recoveryRequired }

final class SaveSyncStatus {
  const SaveSyncStatus(this.phase, {this.conflict});
  final SaveSyncPhase phase;
  final CheckpointConflict? conflict;
}

/// Serializes local persistence and uploads immutable snapshots. Confirmation
/// advances ancestry only when the uploaded checkpoint is still the local head.
final class CheckpointSyncCoordinator {
  CheckpointSyncCoordinator({
    required LocalSaveStore store,
    required CheckpointGateway gateway,
  }) : _store = store,
       _gateway = gateway;

  final LocalSaveStore _store;
  final CheckpointGateway _gateway;
  PlayerSave? _head;
  SaveSyncStatus status = const SaveSyncStatus(SaveSyncPhase.saved);

  PlayerSave? get head => _head;

  Future<PlayerSave?> restore({
    required String environment,
    required String playerId,
  }) async {
    final restored = await _store.restore(
      environment: environment,
      playerId: playerId,
    );
    _head = restored?.save;
    if (restored?.source == LocalSaveSource.backup) {
      status = const SaveSyncStatus(SaveSyncPhase.recoveryRequired);
    }
    return _head;
  }

  Future<void> persist(PlayerSave save) async {
    await _store.replace(save);
    _head = save.sealed();
    status = const SaveSyncStatus(SaveSyncPhase.saved);
  }

  Future<CheckpointResult> synchronize() async {
    final uploading = _head;
    if (uploading == null) {
      return const CheckpointRejected('missing_save', 'No local save exists.');
    }
    status = const SaveSyncStatus(SaveSyncPhase.syncing);
    CheckpointResult result;
    try {
      result = await _gateway.submit(uploading);
    } catch (_) {
      status = const SaveSyncStatus(SaveSyncPhase.offline);
      rethrow;
    }
    switch (result) {
      case CheckpointAccepted(
        :final checkpointId,
        :final revision,
        :final reconciliationCursor,
      ):
        if (_head?.checkpointId == checkpointId) {
          final confirmed = _copy(
            uploading,
            ancestorRevision: revision,
            reconciliationCursor: reconciliationCursor,
          );
          await _store.replace(confirmed);
          _head = confirmed.sealed();
        }
        status = const SaveSyncStatus(SaveSyncPhase.saved);
      case CheckpointConflict():
        status = SaveSyncStatus(SaveSyncPhase.conflict, conflict: result);
      case CheckpointRejected():
        status = const SaveSyncStatus(SaveSyncPhase.recoveryRequired);
    }
    return result;
  }

  Future<void> selectLocalBranch() async {
    final local = _head;
    if (local == null || status.conflict == null) return;
    await _store.preserveBranch(status.conflict!.cloud.save, reason: 'cloud');
    // It remains based on its original ancestor and must pass validation.
    status = const SaveSyncStatus(SaveSyncPhase.saved);
  }

  Future<void> selectCloudBranch() async {
    final local = _head;
    final cloud = status.conflict?.cloud;
    if (local == null || cloud == null) return;
    await _store.preserveBranch(local, reason: 'local');
    await _store.replace(cloud.save);
    _head = cloud.save.sealed();
    status = const SaveSyncStatus(SaveSyncPhase.saved);
  }

  Future<void> reconcile() async {
    var save = _head;
    if (save == null) return;
    final deliveries = await _gateway.fetchInteractions(
      afterCursor: save.reconciliationCursor,
    );
    for (final delivery in deliveries) {
      if (save!.appliedInteractionIds.contains(delivery.interactionId)) {
        continue;
      }
      // Effects are durable receipts. Feature reducers consume the namespaced
      // effect payload; retaining it prevents restoration from erasing it.
      final receipts = List<String>.of(save.appliedInteractionIds)
        ..add(delivery.interactionId);
      final effects = List<Object?>.of(
        (save.payload['sharedInteractionEffects'] as List<Object?>?) ??
            const [],
      )..add(delivery.effect);
      save = _copy(
        save,
        reconciliationCursor: delivery.sequence,
        appliedInteractionIds: receipts,
        payload: {...save.payload, 'sharedInteractionEffects': effects},
      );
    }
    if (!identical(save, _head)) await persist(save!);
  }

  PlayerSave _copy(
    PlayerSave source, {
    int? ancestorRevision,
    int? reconciliationCursor,
    List<String>? appliedInteractionIds,
    Map<String, Object?>? payload,
  }) => PlayerSave(
    checkpointId: source.checkpointId,
    playerId: source.playerId,
    environment: source.environment,
    ancestorRevision: ancestorRevision ?? source.ancestorRevision,
    rulesVersion: source.rulesVersion,
    contentVersion: source.contentVersion,
    reconciliationCursor: reconciliationCursor ?? source.reconciliationCursor,
    createdAt: source.createdAt,
    updatedAt: DateTime.now().toUtc(),
    payload: payload ?? source.payload,
    evidence: source.evidence,
    appliedInteractionIds:
        appliedInteractionIds ?? source.appliedInteractionIds,
  );
}
