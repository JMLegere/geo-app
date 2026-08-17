enum CellKnowledgeState {
  present,
  informed,
  explored,
  shrouded,
}

enum CellRelationship {
  present,
  explored,
  frontier,
  unknown,
}

enum CellContents {
  empty,
  hasLoot,
}

class CellState {
  const CellState({
    CellKnowledgeState? knowledgeState,
    String? category,
    required this.relationship,
    required this.contents,
  })  : knowledgeState = knowledgeState == CellKnowledgeState.informed &&
                (category == null || category == '')
            ? CellKnowledgeState.shrouded
            : knowledgeState ??
                (relationship == CellRelationship.present
                    ? CellKnowledgeState.present
                    : relationship == CellRelationship.explored
                        ? CellKnowledgeState.explored
                        : CellKnowledgeState.shrouded),
        category = (knowledgeState ??
                        (relationship == CellRelationship.present
                            ? CellKnowledgeState.present
                            : relationship == CellRelationship.explored
                                ? CellKnowledgeState.explored
                                : CellKnowledgeState.shrouded)) ==
                    CellKnowledgeState.informed &&
                category != null &&
                category != ''
            ? category
            : null;

  final CellKnowledgeState knowledgeState;
  final String? category;
  final CellRelationship relationship;
  final CellContents contents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellState &&
          runtimeType == other.runtimeType &&
          knowledgeState == other.knowledgeState &&
          category == other.category &&
          relationship == other.relationship &&
          contents == other.contents;

  @override
  int get hashCode =>
      Object.hash(knowledgeState, category, relationship, contents);
}
