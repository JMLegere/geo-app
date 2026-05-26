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
        expect(color.a, greaterThan(0.10));
        expect(color.a, lessThan(0.25));
        expect(color.r, greaterThan(color.b));
      });

      test('frontier cells dim the map without becoming black void', () {
        final color = FogRenderer.fillColor(_state(CellRelationship.frontier));

        expect(color.a, greaterThan(0.20));
        expect(color.a, lessThan(0.36));
        expect(color.r, 0.0);
        expect(color.g, 0.0);
        expect(color.b, 0.0);
      });

      test('unknown cells fully hide non-frontier map details', () {
        final frontier =
            FogRenderer.fillColor(_state(CellRelationship.frontier));
        final unknown = FogRenderer.fillColor(_state(CellRelationship.unknown));

        expect(unknown.a, 1.0);
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

      test('explored mosaic seams use dark neutral contrast', () {
        final explored =
            FogRenderer.strokeColor(_state(CellRelationship.explored));

        expect(explored.a, greaterThanOrEqualTo(0.70));
        expect(explored.r, lessThanOrEqualTo(0.35));
        expect(explored.g, lessThanOrEqualTo(0.35));
        expect(explored.b, lessThanOrEqualTo(0.35));
        expect((explored.r - explored.g).abs(), lessThanOrEqualTo(0.04));
        expect((explored.g - explored.b).abs(), lessThanOrEqualTo(0.04));
      });

      test('frontier inherits a visible border while unknown stays hidden', () {
        final frontier =
            FogRenderer.strokeColor(_state(CellRelationship.frontier));
        final unknown =
            FogRenderer.strokeColor(_state(CellRelationship.unknown));

        expect(frontier.a, greaterThanOrEqualTo(0.70));
        expect(unknown.a, 0.0);
      });
    });

    test('overlay fills are antialiased to soften reveal boundaries', () {
      expect(FogRenderer.overlayAntiAlias, isTrue);
    });

    group('seam styling', () {
      test('frontier keeps a readable seam while unknown stays borderless', () {
        final frontier = _state(CellRelationship.frontier);
        final unknown = _state(CellRelationship.unknown);

        expect(FogRenderer.seamGlowStrokeWidth(frontier),
            greaterThanOrEqualTo(0.9));
        expect(
            FogRenderer.seamStrokeWidth(frontier), greaterThanOrEqualTo(0.55));
        expect(FogRenderer.seamGlowStrokeWidth(unknown), 0.0);
        expect(FogRenderer.seamStrokeWidth(unknown), 0.0);
      });

      test(
          'present and explored seams are thin readable revealed-cell boundaries',
          () {
        final present = _state(CellRelationship.present);
        final explored = _state(CellRelationship.explored);
        final exploredStroke =
            FogRenderer.strokeColor(_state(CellRelationship.explored));

        expect(FogRenderer.seamGlowStrokeWidth(present),
            greaterThanOrEqualTo(1.5));
        expect(
            FogRenderer.seamGlowStrokeWidth(present), lessThanOrEqualTo(1.8));
        expect(FogRenderer.seamGlowStrokeWidth(explored),
            greaterThanOrEqualTo(0.9));
        expect(
            FogRenderer.seamGlowStrokeWidth(explored), lessThanOrEqualTo(1.1));
        expect(FogRenderer.seamStrokeWidth(present), greaterThanOrEqualTo(0.9));
        expect(FogRenderer.seamStrokeWidth(present), lessThanOrEqualTo(1.1));
        expect(
            FogRenderer.seamStrokeWidth(explored), greaterThanOrEqualTo(0.55));
        expect(FogRenderer.seamStrokeWidth(explored), lessThanOrEqualTo(0.7));
        expect(FogRenderer.seamGlowBlurSigma(present), lessThanOrEqualTo(0.8));
        expect(FogRenderer.seamGlowBlurSigma(explored), lessThanOrEqualTo(0.6));
        expect(exploredStroke.a, greaterThanOrEqualTo(0.70));
      });

      test('only unknown glow blur is disabled', () {
        final frontier = _state(CellRelationship.frontier);
        final unknown = _state(CellRelationship.unknown);

        expect(FogRenderer.seamGlowBlurSigma(frontier), greaterThan(0.0));
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
