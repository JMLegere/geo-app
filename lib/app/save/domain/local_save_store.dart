import 'player_save.dart';

enum LocalSaveSource { primary, backup }

final class RestoredPlayerSave {
  const RestoredPlayerSave(this.save, this.source);
  final PlayerSave save;
  final LocalSaveSource source;
}

abstract interface class LocalSaveStore {
  Future<RestoredPlayerSave?> restore({
    required String environment,
    required String playerId,
  });

  /// Atomically rotates primary to backup and publishes [save].
  Future<void> replace(PlayerSave save);

  Future<void> preserveBranch(PlayerSave save, {required String reason});

  Future<void> purge({required String environment, required String playerId});
}

final class LocalSaveStorageException implements Exception {
  const LocalSaveStorageException(this.message);
  final String message;
}
