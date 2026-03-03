import 'package:fog_of_world/features/sync/models/sync_exception.dart';
import 'package:fog_of_world/features/sync/services/cloud_sync_client.dart';

/// In-memory [CloudSyncClient] for development and testing.
///
/// Stores uploaded data in [Map]s keyed by table name. Simulates 200 ms of
/// network latency on every operation. Toggle [simulateError] to force all
/// operations to throw [SyncException], which is useful for testing error
/// handling paths.
class MockCloudSyncClient implements CloudSyncClient {
  MockCloudSyncClient();

  /// In-memory store: table name → list of row maps.
  final Map<String, List<Map<String, dynamic>>> _store = {};

  /// When true, every upload/download throws a [SyncException].
  bool simulateError = false;

  static const _latency = Duration(milliseconds: 200);

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _delay() => Future<void>.delayed(_latency);

  void _throwIfError() {
    if (simulateError) {
      throw const SyncException(
        'Simulated network error',
        code: 'MOCK_ERROR',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // CloudSyncClient implementation
  // ---------------------------------------------------------------------------

  @override
  Future<void> uploadCellProgress(List<Map<String, dynamic>> rows) async {
    await _delay();
    _throwIfError();
    final existing = _store['cell_progress'] ?? [];
    _store['cell_progress'] = [...existing, ...rows];
  }

  @override
  Future<void> uploadCollectedSpecies(List<Map<String, dynamic>> rows) async {
    await _delay();
    _throwIfError();
    final existing = _store['collected_species'] ?? [];
    _store['collected_species'] = [...existing, ...rows];
  }

  @override
  Future<void> uploadProfile(Map<String, dynamic> profile) async {
    await _delay();
    _throwIfError();
    final profiles = List<Map<String, dynamic>>.from(_store['profiles'] ?? []);
    final idx = profiles.indexWhere((p) => p['id'] == profile['id']);
    if (idx >= 0) {
      profiles[idx] = profile;
    } else {
      profiles.add(profile);
    }
    _store['profiles'] = profiles;
  }

  @override
  Future<List<Map<String, dynamic>>> downloadCellProgress(
    String userId,
  ) async {
    await _delay();
    _throwIfError();
    return (_store['cell_progress'] ?? [])
        .where((r) => r['userId'] == userId)
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> downloadCollectedSpecies(
    String userId,
  ) async {
    await _delay();
    _throwIfError();
    return (_store['collected_species'] ?? [])
        .where((r) => r['userId'] == userId)
        .toList();
  }

  @override
  Future<Map<String, dynamic>?> downloadProfile(String userId) async {
    await _delay();
    _throwIfError();
    final profiles = _store['profiles'] ?? [];
    try {
      return profiles.firstWhere((p) => p['id'] == userId);
    } catch (_) {
      return null;
    }
  }
}
