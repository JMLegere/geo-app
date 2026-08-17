import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class CellKnowledgeProjection {
  const CellKnowledgeProjection({
    required this.cellId,
    required CellKnowledgeState state,
    String? category,
  })  : state = state == CellKnowledgeState.informed &&
                (category == null || category == '')
            ? CellKnowledgeState.shrouded
            : state,
        category = state == CellKnowledgeState.informed &&
                category != null &&
                category != ''
            ? category
            : null;

  final String cellId;
  final CellKnowledgeState state;
  final String? category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellKnowledgeProjection &&
          runtimeType == other.runtimeType &&
          cellId == other.cellId &&
          state == other.state &&
          category == other.category;

  @override
  int get hashCode => Object.hash(cellId, state, category);
}
