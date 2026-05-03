class ExploredFootprintProjection {
  ExploredFootprintProjection({
    required Set<String> visitedCellIds,
    required this.persistedCount,
    required this.optimisticCount,
    required this.overlapCount,
  }) : visitedCellIds = Set.unmodifiable(visitedCellIds);

  final Set<String> visitedCellIds;
  final int persistedCount;
  final int optimisticCount;
  final int overlapCount;

  int get uniqueCount => visitedCellIds.length;

  bool wouldAddToFootprint(String cellId) => !visitedCellIds.contains(cellId);

  Map<String, int> toLogData() {
    return {
      'footprint_unique_count': uniqueCount,
      'footprint_persisted_count': persistedCount,
      'footprint_optimistic_count': optimisticCount,
      'footprint_overlap_count': overlapCount,
    };
  }
}

class ExploredFootprintService {
  const ExploredFootprintService();

  ExploredFootprintProjection project({
    required Set<String> persistedVisitedCellIds,
    required Set<String> optimisticVisitedCellIds,
  }) {
    final overlap = persistedVisitedCellIds.intersection(optimisticVisitedCellIds);
    final visitedCellIds = {
      ...persistedVisitedCellIds,
      ...optimisticVisitedCellIds,
    };

    return ExploredFootprintProjection(
      visitedCellIds: visitedCellIds,
      persistedCount: persistedVisitedCellIds.length,
      optimisticCount: optimisticVisitedCellIds.length,
      overlapCount: overlap.length,
    );
  }
}
