import 'package:earth_nova/features/map/domain/entities/map_level.dart';

class HierarchyProgressSummary {
  const HierarchyProgressSummary({
    required this.id,
    required this.name,
    required this.level,
    required this.cellsVisited,
    required this.cellsTotal,
    required this.progressPercent,
    required this.rank,
  });

  final String id;
  final String name;
  final MapLevel level;
  final int cellsVisited;
  final int cellsTotal;
  final double progressPercent;
  final int rank;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HierarchyProgressSummary &&
        other.id == id &&
        other.name == name &&
        other.level == level &&
        other.cellsVisited == cellsVisited &&
        other.cellsTotal == cellsTotal &&
        other.progressPercent == progressPercent &&
        other.rank == rank;
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        level,
        cellsVisited,
        cellsTotal,
        progressPercent,
        rank,
      );
}

abstract class HierarchyRepository {
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  });

  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  });
}
