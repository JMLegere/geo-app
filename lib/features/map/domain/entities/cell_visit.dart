class CellVisit {
  CellVisit({
    required this.id,
    required this.cellId,
    required this.userId,
    required this.visitedAt,
    String? clientEventId,
  }) : clientEventId = _validatedClientEventId(clientEventId);

  final String id;
  final String cellId;
  final String userId;
  final DateTime visitedAt;
  final String? clientEventId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellVisit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cellId == other.cellId &&
          userId == other.userId &&
          visitedAt == other.visitedAt &&
          clientEventId == other.clientEventId;

  @override
  int get hashCode => Object.hash(id, cellId, userId, visitedAt, clientEventId);

  static String? _validatedClientEventId(String? value) {
    if (value == null) return null;
    if (value.isEmpty || value != value.trim()) {
      throw ArgumentError.value(
        value,
        'clientEventId',
        'must be nonblank and already trimmed',
      );
    }
    return value;
  }
}
