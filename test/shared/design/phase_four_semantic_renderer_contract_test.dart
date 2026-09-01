import 'dart:io';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';
import 'package:earth_nova/shared/design.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

CellState _state(CellKnowledgeState knowledgeState) => CellState(
  knowledgeState: knowledgeState,
  category: knowledgeState == CellKnowledgeState.informed ? 'known' : null,
  relationship: switch (knowledgeState) {
    CellKnowledgeState.present => CellRelationship.present,
    CellKnowledgeState.explored => CellRelationship.explored,
    CellKnowledgeState.informed => CellRelationship.frontier,
    CellKnowledgeState.shrouded => CellRelationship.unknown,
  },
  contents: CellContents.empty,
);

void _expectGrayscale(Color color) {
  expect(color.r, color.g);
  expect(color.g, color.b);
}

void main() {
  group('Phase 4 semantic renderer contracts', () {
    test('assigns only calibrated semantic ownership to Map render surfaces', () {
      final surfaces = {
        for (final surface in designSurfaceInventory) surface.path: surface,
      };

      expect(
        surfaces['lib/features/map/presentation/painters/cell_overlay_painter.dart']!
            .designSystemNotes,
        contains('Phase 4 Fog composition'),
      );
      expect(
        surfaces['lib/features/map/presentation/painters/player_marker.dart']!
            .designSystemNotes,
        contains('one marker system'),
      );
      expect(
        surfaces['lib/features/map/presentation/widgets/hierarchy_exploration_map.dart']!
            .designSystemNotes,
        contains('child summary counts and fixed-tile presentation behavior'),
      );
      expect(
        surfaces['lib/features/map/presentation/widgets/district_footprint_map.dart']!
            .designSystemNotes,
        contains('organic cell topology'),
      );
    });

    test('keeps renderer sources free of retired theme and hue semantics', () {
      const rendererPaths = [
        'lib/features/map/presentation/painters/fog_renderer.dart',
        'lib/features/map/presentation/painters/player_marker.dart',
        'lib/features/map/presentation/widgets/hierarchy_exploration_map.dart',
        'lib/features/map/presentation/widgets/district_footprint_map.dart',
      ];
      final retiredThemeOrHue = RegExp(
        r'\bAppTheme\b|\bColors\.(?:green|teal|lime|amber|orange|yellow)\b',
        caseSensitive: false,
      );

      for (final path in rendererPaths) {
        expect(
          retiredThemeOrHue.hasMatch(File(path).readAsStringSync()),
          isFalse,
          reason: '$path must use calibrated neutral renderer semantics.',
        );
      }

      final fog = File(rendererPaths.first).readAsStringSync();
      expect(fog, isNot(contains('D8C49A')));
      for (final state in CellKnowledgeState.values) {
        expect(
          fog,
          contains('CellKnowledgeState.${state.name}'),
          reason:
              'Fog source must keep ${state.name} as an explicit semantic state.',
        );
      }
    });

    test('keeps retained marker trust language without a parallel marker', () {
      final source = File(
        'lib/features/map/presentation/painters/player_marker.dart',
      ).readAsStringSync();

      for (final label in [
        'Player location trusted',
        'Player location low confidence',
        'Player location paused',
      ]) {
        expect(source, contains(label));
      }
      expect(RegExp(r'\bCustomPaint\s*\(').allMatches(source), hasLength(1));
    });

    test(
      'distinguishes informed and explored with grayscale-safe Fog fills',
      () {
        final fills = {
          for (final state in CellKnowledgeState.values)
            state: FogRenderer.fillColor(_state(state)),
        };

        expect(
          fills.values.toSet(),
          hasLength(CellKnowledgeState.values.length),
        );
        expect(
          fills[CellKnowledgeState.informed],
          isNot(equals(fills[CellKnowledgeState.explored])),
        );
        for (final fill in fills.values) {
          _expectGrayscale(fill);
        }
        expect(
          FogRenderer.strokeColor(_state(CellKnowledgeState.present)).a,
          greaterThan(
            FogRenderer.strokeColor(_state(CellKnowledgeState.explored)).a,
          ),
        );
      },
    );
  });
}
