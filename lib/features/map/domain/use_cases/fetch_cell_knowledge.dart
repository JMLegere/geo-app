import 'package:earth_nova/core/observability/observable_use_case.dart';
import 'package:earth_nova/core/observability/observability_service.dart';
import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';
import 'package:earth_nova/features/map/domain/repositories/cell_knowledge_repository.dart';

typedef FetchCellKnowledgeInput = ({Iterable<String> cellIds});

class FetchCellKnowledge extends ObservableUseCase<FetchCellKnowledgeInput,
    Map<String, CellKnowledgeProjection>> {
  FetchCellKnowledge(this._repository, this._obs);

  final CellKnowledgeRepository _repository;
  final ObservabilityService _obs;

  @override
  ObservabilityService get obs => _obs;

  @override
  String get operationName => 'fetch_cell_knowledge';

  @override
  Future<Map<String, CellKnowledgeProjection>> execute(
    FetchCellKnowledgeInput input,
    String traceId,
  ) =>
      _repository.fetchForCells(input.cellIds, traceId: traceId);
}
