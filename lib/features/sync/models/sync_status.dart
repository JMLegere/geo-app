/// The current phase of a sync operation.
enum SyncStatusType { idle, syncing, success, error }

/// Sentinel used by [SyncStatus.copyWith] to distinguish "clear to null"
/// from "leave unchanged" for nullable String fields.
const _clearString = Object();

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
  /// To explicitly clear a nullable field to null, pass the [clearError]
  /// sentinel constant instead of a string value:
  ///
  /// ```dart
  /// state = state.copyWith(errorMessage: clearError);
  /// ```
  SyncStatus copyWith({
    SyncStatusType? type,
    DateTime? lastSyncedAt,
    Object? errorMessage =
        _clearString, // sentinel: _clearString = keep current
    int? pendingChanges,
  }) {
    return SyncStatus(
      type: type ?? this.type,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      errorMessage: identical(errorMessage, _clearString)
          ? this.errorMessage
          : errorMessage as String?,
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
