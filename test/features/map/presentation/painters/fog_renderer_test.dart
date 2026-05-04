import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

CellState _state(CellRelationship relationship) => CellState(
      relationship: relationship,
      contents: CellContents.empty,
    );

void main() {
  group('FogRenderer', () {
    group('fillColor', () {
      test('present/current cells are fully clear', () {
        final color = FogRenderer.fillColor(_state(CellRelationship.present));

        expect(color.a, 0.0);
      });

      test('explored cells use a faded parchment veil', () {
        final color = FogRenderer.fillColor(_state(CellRelationship.explored));

        expect(color.a, greaterThan(0.0));
        expect(color.a, lessThan(0.5));
        expect(color.r, greaterThan(color.b));
      });

      test('frontier cells dim the map without becoming black void', () {
        final color = FogRenderer.fillColor(_state(CellRelationship.frontier));

        expect(color.a, greaterThan(0.40));
        expect(color.a, lessThan(0.56));
        expect(color.r, 0.0);
        expect(color.g, 0.0);
        expect(color.b, 0.0);
      });

      test('unknown cells are more opaque than frontier cells', () {
        final frontier =
            FogRenderer.fillColor(_state(CellRelationship.frontier));
        final unknown = FogRenderer.fillColor(_state(CellRelationship.unknown));

        expect(unknown.a, greaterThan(frontier.a));
      });
    });

    group('strokeColor', () {
      test('present and explored states keep the habitat boundary channel', () {
        final present =
            FogRenderer.strokeColor(_state(CellRelationship.present));
        final explored =
            FogRenderer.strokeColor(_state(CellRelationship.explored));

        expect(present.a, greaterThan(0.0));
        expect(explored.a, greaterThan(0.0));
      });

      test('frontier and unknown seams are hidden so fog does not form a grid',
          () {
        final frontier =
            FogRenderer.strokeColor(_state(CellRelationship.frontier));
        final unknown =
            FogRenderer.strokeColor(_state(CellRelationship.unknown));

        expect(frontier.a, 0.0);
        expect(unknown.a, 0.0);
      });
    });

    group('seam styling', () {
      test('frontier and unknown glow widths are zero', () {
        final frontier = _state(CellRelationship.frontier);
        final unknown = _state(CellRelationship.unknown);

        expect(FogRenderer.seamGlowStrokeWidth(frontier), 0.0);
        expect(FogRenderer.seamGlowStrokeWidth(unknown), 0.0);
        expect(FogRenderer.seamStrokeWidth(frontier), 0.0);
        expect(FogRenderer.seamStrokeWidth(unknown), 0.0);
      });

      test('frontier and unknown glow blur is disabled', () {
        final frontier = _state(CellRelationship.frontier);
        final unknown = _state(CellRelationship.unknown);

        expect(FogRenderer.seamGlowBlurSigma(frontier), 0.0);
        expect(FogRenderer.seamGlowBlurSigma(unknown), 0.0);
      });
    });

    group('animation', () {
      test('only frontier fog animates', () {
        expect(
            FogRenderer.animatesFog(_state(CellRelationship.present)), isFalse);
        expect(FogRenderer.animatesFog(_state(CellRelationship.explored)),
            isFalse);
        expect(
            FogRenderer.animatesFog(_state(CellRelationship.frontier)), isTrue);
        expect(
            FogRenderer.animatesFog(_state(CellRelationship.unknown)), isFalse);
      });
    });

    group('shouldRender', () {
      test('all visible reveal states are renderable', () {
        for (final relationship in CellRelationship.values) {
          expect(
            FogRenderer.shouldRender(_state(relationship)),
            isTrue,
            reason: relationship.name,
          );
        }
      });

      test('cell with loot is rendered regardless of reveal state', () {
        const frontierWithLoot = CellState(
          relationship: CellRelationship.frontier,
          contents: CellContents.hasLoot,
        );

        expect(FogRenderer.shouldRender(frontierWithLoot), isTrue);
      });
    });
  });
}
