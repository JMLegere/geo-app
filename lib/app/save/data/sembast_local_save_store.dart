import 'dart:convert';

import 'package:sembast/sembast.dart';

import '../domain/local_save_store.dart';
import '../domain/player_save.dart';

final class SembastLocalSaveStore implements LocalSaveStore {
  SembastLocalSaveStore(this._database);

  final Future<Database> _database;
  final StoreRef<String, String> _store = StoreRef<String, String>(
    'player_saves',
  );

  @override
  Future<RestoredPlayerSave?> restore({
    required String environment,
    required String playerId,
  }) async {
    final database = await _database;
    final prefix = _key(environment, playerId);
    for (final candidate in const [
      (suffix: 'primary', source: LocalSaveSource.primary),
      (suffix: 'backup', source: LocalSaveSource.backup),
    ]) {
      final raw = await _store
          .record('$prefix.${candidate.suffix}')
          .get(database);
      if (raw == null) continue;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) throw const FormatException();
        final save = PlayerSave.fromJson(Map<String, Object?>.from(decoded));
        if (save.environment != environment || save.playerId != playerId) {
          throw const PlayerSaveFormatException('Save binding mismatch.');
        }
        return RestoredPlayerSave(save, candidate.source);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  @override
  Future<void> replace(PlayerSave save) async {
    final sealed = save.sealed();
    final encoded = jsonEncode(sealed.toJson());
    if (utf8.encode(encoded).length > maximumPlayerSaveBytes) {
      throw const LocalSaveStorageException('Save exceeds the storage limit.');
    }
    try {
      final database = await _database;
      final prefix = _key(save.environment, save.playerId);
      await database.transaction((transaction) async {
        final primary = _store.record('$prefix.primary');
        final existing = await primary.get(transaction);
        if (existing != null) {
          await _store.record('$prefix.backup').put(transaction, existing);
        }
        await primary.put(transaction, encoded);
      });
    } catch (error) {
      throw LocalSaveStorageException('Atomic save replacement failed: $error');
    }
  }

  @override
  Future<void> preserveBranch(PlayerSave save, {required String reason}) async {
    final safeReason = reason.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
    final database = await _database;
    await _store
        .record(
          '${_key(save.environment, save.playerId)}.branch.'
          '${save.checkpointId}.$safeReason',
        )
        .put(database, jsonEncode(save.sealed().toJson()));
  }

  @override
  Future<void> purge({
    required String environment,
    required String playerId,
  }) async {
    final database = await _database;
    final prefix = _key(environment, playerId);
    await _store.delete(
      database,
      finder: Finder(
        filter: Filter.custom((record) {
          final key = record.key;
          return key is String && key.startsWith('$prefix.');
        }),
      ),
    );
  }

  String _key(String environment, String playerId) =>
      '${Uri.encodeComponent(environment)}.${Uri.encodeComponent(playerId)}';
}
