/// The current phase of a sync operation.
enum SyncStatusType { idle, syncing, success, error }

/// Immutable snapshot of sync state shown in the UI.
class SyncStatus {
  const SyncStatus({
    required this.type,
    this.lastSyncedAt,
    this.errorMessage,
    this.pendingChanges = 0,
  });

  final SyncStatusType type;
  final DateTime? lastSyncedAt;
  final String? errorMessage;

  /// Number of items in the local sync queue awaiting upload.
  final int pendingChanges;

  /// Returns a copy with the supplied fields replaced.
  ///
  /// Note: nullable fields ([lastSyncedAt], [errorMessage]) are NOT clearable
  /// via copyWith — construct a new [SyncStatus] directly when you need to
  /// explicitly set them to null.
  SyncStatus copyWith({
    SyncStatusType? type,
    DateTime? lastSyncedAt,
    String? errorMessage,
    int? pendingChanges,
  }) {
    return SyncStatus(
      type: type ?? this.type,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      pendingChanges: pendingChanges ?? this.pendingChanges,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SyncStatus &&
        other.type == type &&
        other.lastSyncedAt == lastSyncedAt &&
        other.errorMessage == errorMessage &&
        other.pendingChanges == pendingChanges;
  }

  @override
  int get hashCode =>
      Object.hash(type, lastSyncedAt, errorMessage, pendingChanges);

  @override
  String toString() => 'SyncStatus(type: $type, lastSyncedAt: $lastSyncedAt, '
      'error: $errorMessage, pending: $pendingChanges)';
}
