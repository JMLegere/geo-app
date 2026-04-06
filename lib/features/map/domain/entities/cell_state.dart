enum CellRelationship {
  present,
  explored,
  nearby,
}

enum CellContents {
  empty,
  hasLoot,
}

class CellState {
  const CellState({
    required this.relationship,
    required this.contents,
  });

  final CellRelationship relationship;
  final CellContents contents;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CellState &&
          runtimeType == other.runtimeType &&
          relationship == other.relationship &&
          contents == other.contents;

  @override
  int get hashCode => Object.hash(relationship, contents);
}
