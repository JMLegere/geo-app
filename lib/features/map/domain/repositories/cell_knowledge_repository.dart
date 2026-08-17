import 'package:earth_nova/features/map/domain/entities/cell_knowledge_projection.dart';

abstract interface class CellKnowledgeRepository {
  Future<Map<String, CellKnowledgeProjection>> fetchForCells(
    Iterable<String> cellIds, {
    String? traceId,
  });
}
