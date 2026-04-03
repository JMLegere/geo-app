import 'package:flutter/foundation.dart';

/// The type of entity being queued for sync.
enum WriteQueueEntityType {
  /// A unique discovered item instance.
  itemInstance,

  /// Cell progress (fog state, distance, visit count).
  cellProgress,

  /// Player profile (streaks, distance, season).
  profile,

  /// Cell properties (habitats, climate, continent, location).
  cellProperties;

  static WriteQueueEntityType fromString(String value) {
    return WriteQueueEntityType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown WriteQueueEntityType: $value'),
    );
  }

  @override
  String toString() => name;
}

/// The operation to perform on the server.
enum WriteQueueOperation {
  /// Insert or update the entity.
  upsert,

  /// Remove the entity.
  delete;

  static WriteQueueOperation fromString(String value) {
    return WriteQueueOperation.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown WriteQueueOperation: $value'),
    );
  }

  @override
  String toString() => name;
}

/// Processing status of a queue entry.
enum WriteQueueStatus {
  /// Awaiting sync to server.
  pending,

  /// Server rejected this entry (validation failed).
  rejected;

  static WriteQueueStatus fromString(String value) {
    return WriteQueueStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown WriteQueueStatus: $value'),
    );
  }

  @override
  String toString() => name;
}

/// A queued write operation awaiting sync to Supabase.
///
/// Each game state change (item discovery, cell visit, profile update)
/// creates one entry. The [QueueProcessor] flushes pending entries to
/// Supabase with retry logic. Confirmed entries are deleted; rejected
/// entries trigger local rollback.
@immutable
class WriteQueueEntry {
  /// Auto-incremented local ID.
  final int? id;

  /// What kind of entity this write targets.
  final WriteQueueEntityType entityType;

  /// The primary key of the entity (e.g. item instance UUID, cell progress ID).
  final String entityId;

  /// Whether to upsert or delete.
  final WriteQueueOperation operation;

  /// JSON-encoded snapshot of the entity at time of queuing.
  final String payload;

  /// The user who owns this data.
  final String userId;

  /// Current processing status.
  final WriteQueueStatus status;

  /// Number of sync attempts so far.
  final int attempts;

  /// Last error message from a failed sync attempt.
  final String? lastError;

  /// When this entry was created.
  final DateTime createdAt;

  /// When this entry was last updated (status change, retry).
  final DateTime updatedAt;

  const WriteQueueEntry({
    this.id,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payload,
    required this.userId,
    this.status = WriteQueueStatus.pending,
    this.attempts = 0,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  WriteQueueEntry copyWith({
    int? id,
    WriteQueueEntityType? entityType,
    String? entityId,
    WriteQueueOperation? operation,
    String? payload,
    String? userId,
    WriteQueueStatus? status,
    int? attempts,
    String? lastError,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WriteQueueEntry(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payload: payload ?? this.payload,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: lastError ?? this.lastError,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WriteQueueEntry &&
        other.id == id &&
        other.entityType == entityType &&
        other.entityId == entityId &&
        other.operation == operation &&
        other.payload == payload &&
        other.userId == userId &&
        other.status == status &&
        other.attempts == attempts &&
        other.lastError == lastError &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode => Object.hash(
        id,
        entityType,
        entityId,
        operation,
        payload,
        userId,
        status,
        attempts,
        lastError,
        createdAt,
        updatedAt,
      );

  @override
  String toString() => 'WriteQueueEntry(id: $id, entityType: $entityType, '
      'entityId: $entityId, operation: $operation, '
      'status: $status, attempts: $attempts)';
}
