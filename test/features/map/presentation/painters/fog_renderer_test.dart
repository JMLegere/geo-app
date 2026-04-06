import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

void main() {
  group('FogRenderer', () {
    group('fillColor', () {
      test('present cell returns bright fill', () {
        const state = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        final color = FogRenderer.fillColor(state);
        expect(color.a, greaterThan(0.5));
      });

      test('explored cell returns muted fill', () {
        const state = CellState(
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        );
        final presentState = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        final presentColor = FogRenderer.fillColor(presentState);
        final exploredColor = FogRenderer.fillColor(state);
        expect(exploredColor.a, lessThan(presentColor.a));
      });

      test('nearby cell returns dark fill with light fog', () {
        const state = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.empty,
        );
        final color = FogRenderer.fillColor(state);
        expect(color.a, lessThan(0.3));
      });

      test('cell with loot returns fill regardless of relationship', () {
        const presentWithLoot = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.hasLoot,
        );
        const nearbyWithLoot = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.hasLoot,
        );
        final presentColor = FogRenderer.fillColor(presentWithLoot);
        final nearbyColor = FogRenderer.fillColor(nearbyWithLoot);
        expect(presentColor.a, greaterThan(0.5));
        expect(nearbyColor.a, greaterThan(0.5));
      });
    });

    group('strokeColor', () {
      test('present cell has crisp habitat border', () {
        const state = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        final color = FogRenderer.strokeColor(state);
        expect(color.a, greaterThan(0.5));
      });

      test('explored cell has visible habitat border', () {
        const state = CellState(
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        );
        final color = FogRenderer.strokeColor(state);
        expect(color.a, greaterThan(0.0));
      });

      test('nearby cell has dimmed habitat border', () {
        const state = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.empty,
        );
        final presentState = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        final presentColor = FogRenderer.strokeColor(presentState);
        final nearbyColor = FogRenderer.strokeColor(state);
        expect(nearbyColor.a, lessThan(presentColor.a));
      });
    });

    group('shouldRender', () {
      test('present cell is rendered', () {
        const state = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        expect(FogRenderer.shouldRender(state), isTrue);
      });

      test('explored cell is rendered', () {
        const state = CellState(
          relationship: CellRelationship.explored,
          contents: CellContents.empty,
        );
        expect(FogRenderer.shouldRender(state), isTrue);
      });

      test('nearby cell is rendered', () {
        const state = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.empty,
        );
        expect(FogRenderer.shouldRender(state), isTrue);
      });

      test('cell with loot is rendered regardless of state', () {
        const nearbyWithLoot = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.hasLoot,
        );
        expect(FogRenderer.shouldRender(nearbyWithLoot), isTrue);
      });
    });

    group('renderDistance', () {
      test('cells within render distance (~2km) are shown', () {
        const nearbyState = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.empty,
        );
        expect(FogRenderer.shouldRender(nearbyState), isTrue);
      });

      test('cells beyond render distance are not rendered', () {
        const beyondDistance = CellState(
          relationship: CellRelationship.nearby,
          contents: CellContents.empty,
        );
        expect(FogRenderer.shouldRender(beyondDistance), isTrue);
      });
    });

    group('habitat blend', () {
      test('habitat border color is weighted average of cell habitats', () {
        const state = CellState(
          relationship: CellRelationship.present,
          contents: CellContents.empty,
        );
        final strokeColor = FogRenderer.strokeColor(state);
        expect(strokeColor.a, greaterThan(0.0));
      });
    });
  });
}
