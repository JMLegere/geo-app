import 'player_save.dart';

sealed class CheckpointResult {
  const CheckpointResult();
}

final class CheckpointAccepted extends CheckpointResult {
  const CheckpointAccepted({
    required this.checkpointId,
    required this.revision,
    required this.reconciliationCursor,
  });
  final String checkpointId;
  final int revision;
  final int reconciliationCursor;
}

final class CheckpointConflict extends CheckpointResult {
  const CheckpointConflict({required this.cloud, required this.reason});
  final PublishedPlayerSave cloud;
  final String reason;
}

final class CheckpointRejected extends CheckpointResult {
  const CheckpointRejected(this.code, this.message);
  final String code;
  final String message;
}

final class PublishedPlayerSave {
  const PublishedPlayerSave({required this.revision, required this.save});
  final int revision;
  final PlayerSave save;
}

abstract interface class CheckpointGateway {
  Future<PublishedPlayerSave?> fetchLatest();
  Future<CheckpointResult> submit(PlayerSave save);
  Future<List<SharedInteractionDelivery>> fetchInteractions({
    required int afterCursor,
  });
}

final class SharedInteractionDelivery {
  const SharedInteractionDelivery({
    required this.interactionId,
    required this.sequence,
    required this.rulesVersion,
    required this.effect,
  });
  final String interactionId;
  final int sequence;
  final String rulesVersion;
  final Map<String, Object?> effect;
}
