import 'package:earth_nova/features/map/domain/entities/map_level.dart';
import 'package:earth_nova/features/map/domain/repositories/hierarchy_repository.dart';

class MockHierarchyRepository implements HierarchyRepository {
  @override
  Future<HierarchyProgressSummary> getScopeSummary({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return HierarchyProgressSummary(
      id: scopeId ?? 'mock-scope',
      name: _mockName(level),
      level: level,
      cellsVisited: 0,
      cellsTotal: 0,
      progressPercent: 0.0,
      rank: 0,
    );
  }

  @override
  Future<List<HierarchyProgressSummary>> getChildSummaries({
    required String userId,
    required MapLevel level,
    String? scopeId,
  }) async {
    return [];
  }

  String _mockName(MapLevel level) {
    return switch (level) {
      MapLevel.cell => 'Cell',
      MapLevel.district => 'District',
      MapLevel.city => 'City',
      MapLevel.state => 'Province',
      MapLevel.country => 'Country',
      MapLevel.world => 'World',
    };
  }
}
