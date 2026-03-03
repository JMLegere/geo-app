/// Abstract contract for cloud sync operations.
///
/// Two implementations:
/// - `MockCloudSyncClient` — in-memory, no network (dev & test).
/// - `SupabaseCloudSyncClient` — real backend (prod, requires credentials).
abstract class CloudSyncClient {
  /// Batch-upsert cell progress rows to the cloud.
  ///
  /// Each map uses the same field names as the local Drift table.
  Future<void> uploadCellProgress(List<Map<String, dynamic>> rows);

  /// Batch-upsert collected species rows to the cloud.
  Future<void> uploadCollectedSpecies(List<Map<String, dynamic>> rows);

  /// Upsert a single player profile to the cloud.
  Future<void> uploadProfile(Map<String, dynamic> profile);

  /// Fetch all cell progress records for [userId] from the cloud.
  Future<List<Map<String, dynamic>>> downloadCellProgress(String userId);

  /// Fetch all collected species records for [userId] from the cloud.
  Future<List<Map<String, dynamic>>> downloadCollectedSpecies(String userId);

  /// Fetch the player profile for [userId] from the cloud, or null if absent.
  Future<Map<String, dynamic>?> downloadProfile(String userId);
}
