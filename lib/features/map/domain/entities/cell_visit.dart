class CellVisit {
  const CellVisit({
    required this.id,
    required this.cellId,
    required this.userId,
    required this.visitedAt,
  });

  final String id;
  final String cellId;
  final String userId;
  final DateTime visitedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellVisit &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          cellId == other.cellId &&
          userId == other.userId &&
          visitedAt == other.visitedAt;

  @override
  int get hashCode => Object.hash(id, cellId, userId, visitedAt);
}
