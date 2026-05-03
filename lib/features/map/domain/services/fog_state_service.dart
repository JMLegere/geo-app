import 'package:earth_nova/features/map/domain/entities/cell.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';

class FogStateService {
  const FogStateService();

  List<({Cell cell, CellState state})> compute({
    required List<Cell> cells,
    required String? currentCellId,
    required Set<String> exploredCellIds,
  }) {

    return cells.map((cell) {
      final relationship = _relationshipFor(
        cellId: cell.id,
        currentCellId: currentCellId,
        exploredCellIds: exploredCellIds,
      );

      return (
        cell: cell,
        state: CellState(
          relationship: relationship,
          contents: CellContents.empty,
        ),
      );
    }).toList(growable: false);
  }

  CellRelationship _relationshipFor({
    required String cellId,
    required String? currentCellId,
    required Set<String> exploredCellIds,
  }) {
    if (cellId == currentCellId) return CellRelationship.present;
    if (exploredCellIds.contains(cellId)) return CellRelationship.explored;
    return CellRelationship.frontier;
  }
}
