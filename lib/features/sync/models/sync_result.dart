/// The outcome of a SyncService.syncAll call.
class SyncResult {
  const SyncResult({
    required this.uploadedCount,
    required this.downloadedCount,
    required this.errorCount,
    this.errorMessage,
  });

  /// Number of local events successfully uploaded to the cloud.
  final int uploadedCount;

  /// Number of remote records successfully merged into local DB.
  final int downloadedCount;

  /// Number of tables/operations that failed during this sync pass.
  final int errorCount;

  /// Human-readable description of the last error, if any.
  final String? errorMessage;

  /// True when no errors occurred during the sync pass.
  bool get isSuccess => errorCount == 0 && errorMessage == null;

  @override
  String toString() => 'SyncResult(uploaded: $uploadedCount, '
      'downloaded: $downloadedCount, errors: $errorCount, '
      'message: $errorMessage)';
}
