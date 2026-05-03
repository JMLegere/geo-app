abstract interface class CellVisitPort {
  Future<void> recordVisit({
    required String userId,
    required String cellId,
    String? traceId,
  });

  Future<Set<String>> getVisitedCellIds({
    required String userId,
    String? traceId,
  });

  Future<bool> isFirstVisit({
    required String userId,
    required String cellId,
    String? traceId,
  });
}
