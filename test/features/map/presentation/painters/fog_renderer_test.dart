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

      test('frontier cells use heavy black fog', () {
        final color = FogRenderer.fillColor(_state(CellRelationship.frontier));

        expect(color.a, greaterThan(0.65));
        expect(color.r, 0.0);
        expect(color.g, 0.0);
        expect(color.b, 0.0);
      });

      test('unknown cells are more opaque than frontier cells', () {
        final frontier = FogRenderer.fillColor(_state(CellRelationship.frontier));
        final unknown = FogRenderer.fillColor(_state(CellRelationship.unknown));

        expect(unknown.a, greaterThan(frontier.a));
      });
    });

    group('strokeColor', () {
      test('all reveal states keep a visible boundary channel', () {
        for (final relationship in CellRelationship.values) {
          final color = FogRenderer.strokeColor(_state(relationship));

          expect(color.a, greaterThan(0.0), reason: relationship.name);
        }
      });

      test('current seam glow is stronger than explored and unknown', () {
        final present = FogRenderer.strokeColor(_state(CellRelationship.present));
        final explored = FogRenderer.strokeColor(_state(CellRelationship.explored));
        final unknown = FogRenderer.strokeColor(_state(CellRelationship.unknown));

        expect(present.a, greaterThan(explored.a));
        expect(present.a, greaterThan(unknown.a));
      });
    });

    group('animation', () {
      test('only frontier fog animates', () {
        expect(FogRenderer.animatesFog(_state(CellRelationship.present)), isFalse);
        expect(FogRenderer.animatesFog(_state(CellRelationship.explored)), isFalse);
        expect(FogRenderer.animatesFog(_state(CellRelationship.frontier)), isTrue);
        expect(FogRenderer.animatesFog(_state(CellRelationship.unknown)), isFalse);
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
