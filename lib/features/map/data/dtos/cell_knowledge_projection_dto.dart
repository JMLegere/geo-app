import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class CellKnowledgeProjectionDto {
  const CellKnowledgeProjectionDto({
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

  factory CellKnowledgeProjectionDto.fromJson(Map<String, Object?> json) {
    final rawCategory = json['category'];
    final category =
        rawCategory is String && _informedCategories.contains(rawCategory)
            ? rawCategory
            : null;
    final state = switch (json['state']) {
      'present' => CellKnowledgeState.present,
      'informed' when category != null => CellKnowledgeState.informed,
      'explored' => CellKnowledgeState.explored,
      'shrouded' => CellKnowledgeState.shrouded,
      _ => CellKnowledgeState.shrouded,
    };

    return CellKnowledgeProjectionDto(
      cellId: json['cell_id'] is String ? json['cell_id'] as String : '',
      state: state,
      category: category,
    );
  }

  Map<String, Object?> toJson() => {
        'cell_id': cellId,
        'state': state.name,
        'category': category,
      };

  CellKnowledgeProjection toDomain() => CellKnowledgeProjection(
        cellId: cellId,
        state: state,
        category: category,
      );

  static const _informedCategories = {
    'fauna',
    'flora',
    'mineral',
    'fossil',
    'artifact',
    'food',
    'orb',
  };
}
