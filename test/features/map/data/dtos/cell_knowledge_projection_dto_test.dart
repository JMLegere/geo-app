import 'package:earth_nova/features/map/data/dtos/cell_knowledge_projection_dto.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CellKnowledgeProjectionDto', () {
    test('parses an informed category without exact cell content', () {
      final projection = CellKnowledgeProjectionDto.fromJson(const {
        'cell_id': 'cell-1',
        'state': 'informed',
        'category': 'fauna',
        'contents': {'exact': 'secret'},
      }).toDomain();

      expect(projection.cellId, 'cell-1');
      expect(projection.state, CellKnowledgeState.informed);
      expect(projection.category, 'fauna');
    });

    test('accepts only canonical informed categories', () {
      const categories = [
        'fauna',
        'flora',
        'mineral',
        'fossil',
        'artifact',
        'food',
        'orb',
      ];

      for (final category in categories) {
        final projection = CellKnowledgeProjectionDto.fromJson({
          'cell_id': 'cell-$category',
          'state': 'informed',
          'category': category,
        }).toDomain();

        expect(projection.state, CellKnowledgeState.informed);
        expect(projection.category, category);
      }
    });

    test('fails closed to Shrouded for an invalid state or category', () {
      final invalidState = CellKnowledgeProjectionDto.fromJson(const {
        'cell_id': 'cell-1',
        'state': 'unexpected',
        'category': 'fauna',
      }).toDomain();
      final invalidCategory = CellKnowledgeProjectionDto.fromJson(const {
        'cell_id': 'cell-2',
        'state': 'informed',
        'category': 'forest',
      }).toDomain();
      final missingInformedCategory =
          CellKnowledgeProjectionDto.fromJson(const {
        'cell_id': 'cell-3',
        'state': 'informed',
      }).toDomain();

      expect(invalidState.state, CellKnowledgeState.shrouded);
      expect(invalidState.category, isNull);
      expect(invalidCategory.state, CellKnowledgeState.shrouded);
      expect(invalidCategory.category, isNull);
      expect(missingInformedCategory.state, CellKnowledgeState.shrouded);
      expect(missingInformedCategory.category, isNull);
    });

    test('drops categories for states other than Informed', () {
      final projection = CellKnowledgeProjectionDto.fromJson(const {
        'cell_id': 'cell-1',
        'state': 'explored',
        'category': 'fauna',
      }).toDomain();

      expect(projection.state, CellKnowledgeState.explored);
      expect(projection.category, isNull);
    });

    test('serializes only the canonical state and category fields', () {
      const dto = CellKnowledgeProjectionDto(
        cellId: 'cell-1',
        state: CellKnowledgeState.informed,
        category: 'fauna',
      );

      expect(dto.toJson(), {
        'cell_id': 'cell-1',
        'state': 'informed',
        'category': 'fauna',
      });
    });
  });
}
