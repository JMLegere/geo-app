import 'pending_command.dart';

abstract interface class PendingCommandStore {
  Future<List<PendingCommand>> load({
    required String environment,
    required String playerId,
    required DateTime now,
  });

  Future<void> enqueue(PendingCommand command);

  Future<void> replace(PendingCommand command);

  Future<void> remove(PendingCommand command);

  Future<void> purge({
    required String environment,
    required String playerId,
  });
}

class QueueStoreFailure implements Exception {
  const QueueStoreFailure(this.safeMessage);
  final String safeMessage;
}

final class QueueCorruptFailure extends QueueStoreFailure {
  const QueueCorruptFailure() : super('Pending command data is invalid.');
}

final class QueueBoundFailure extends QueueStoreFailure {
  const QueueBoundFailure() : super('Pending command storage is full.');
}

final class QueueWriteFailure extends QueueStoreFailure {
  const QueueWriteFailure() : super('Pending command data could not be saved.');
}
