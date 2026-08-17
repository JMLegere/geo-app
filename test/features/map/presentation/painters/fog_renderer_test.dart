import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

CellState _state(
  CellKnowledgeState knowledgeState, {
  String? category,
  CellContents contents = CellContents.empty,
}) =>
    CellState(
      knowledgeState: knowledgeState,
      category: category,
      relationship: switch (knowledgeState) {
        CellKnowledgeState.present => CellRelationship.present,
        CellKnowledgeState.explored => CellRelationship.explored,
        CellKnowledgeState.informed => CellRelationship.frontier,
        CellKnowledgeState.shrouded => CellRelationship.unknown,
      },
      contents: contents,
    );

void main() {
  group('FogRenderer canonical Cell knowledge', () {
    test('uses four static native treatments', () {
      final states = {
        for (final knowledgeState in CellKnowledgeState.values)
          knowledgeState: _state(knowledgeState),
      };

      expect(FogRenderer.fillColor(states[CellKnowledgeState.present]!).a, 0);
      expect(
        FogRenderer.fillColor(states[CellKnowledgeState.explored]!).a,
        inExclusiveRange(0, 1),
      );
      expect(
        FogRenderer.fillColor(states[CellKnowledgeState.shrouded]!).a,
        1,
      );
      expect(
        FogRenderer.strokeColor(states[CellKnowledgeState.shrouded]!).a,
        0,
      );
      for (final state in states.values) {
        expect(
          FogRenderer.animatesFog(state),
          isFalse,
          reason: '${state.knowledgeState.name} must remain static',
        );
      }
    });

    test('Informed reuses the Explored base treatment', () {
      final informed = _state(
        CellKnowledgeState.informed,
        category: 'fauna',
      );
      final explored = _state(CellKnowledgeState.explored);

      expect(FogRenderer.fillColor(informed), FogRenderer.fillColor(explored));
      expect(
        FogRenderer.strokeColor(informed),
        FogRenderer.strokeColor(explored),
      );
      expect(
        FogRenderer.seamGlowStrokeWidth(informed),
        FogRenderer.seamGlowStrokeWidth(explored),
      );
      expect(
        FogRenderer.seamStrokeWidth(informed),
        FogRenderer.seamStrokeWidth(explored),
      );
      expect(
        FogRenderer.seamGlowBlurSigma(informed),
        FogRenderer.seamGlowBlurSigma(explored),
      );
    });

    test('reduced motion keeps every fog state static', () {
      for (final knowledgeState in CellKnowledgeState.values) {
        expect(FogRenderer.animatesFog(_state(knowledgeState)), isFalse);
      }
    });

    test('legacy hasLoot never changes canonical fog treatment', () {
      for (final knowledgeState in CellKnowledgeState.values) {
        final empty = _state(knowledgeState);
        final legacyLoot = _state(
          knowledgeState,
          contents: CellContents.hasLoot,
        );

        expect(FogRenderer.fillColor(legacyLoot), FogRenderer.fillColor(empty));
        expect(
          FogRenderer.strokeColor(legacyLoot),
          FogRenderer.strokeColor(empty),
        );
        expect(
          FogRenderer.shouldRender(legacyLoot),
          FogRenderer.shouldRender(empty),
        );
      }
    });

    test('overlay fills stay antialiased at native map resolution', () {
      expect(FogRenderer.overlayAntiAlias, isTrue);
    });
  });
}
