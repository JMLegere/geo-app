import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/features/map/domain/entities/cell_state.dart';
import 'package:earth_nova/features/map/presentation/painters/fog_renderer.dart';

CellState _state(
  CellKnowledgeState knowledgeState, {
  String? category,
  CellContents contents = CellContents.empty,
}) => CellState(
  knowledgeState: knowledgeState,
  category: knowledgeState == CellKnowledgeState.informed
      ? category ?? 'fauna'
      : category,
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
    test('uses four distinct static grayscale-safe reveal treatments', () {
      final fills = [
        for (final knowledgeState in const [
          CellKnowledgeState.present,
          CellKnowledgeState.explored,
          CellKnowledgeState.informed,
          CellKnowledgeState.shrouded,
        ])
          FogRenderer.fillColor(_state(knowledgeState)),
      ];

      expect(fills.toSet(), hasLength(4));
      expect(
        fills.map((color) => color.a),
        orderedEquals(fills.map((color) => color.a).toList()..sort()),
        reason: 'Present must be clearest and Shrouded most concealed.',
      );
      expect(
        {for (final fill in fills) (fill.r, fill.g, fill.b)},
        hasLength(1),
        reason: 'Knowledge must remain legible without hue.',
      );
      expect(fills.first.a, 0);
      expect(fills.last.a, 1);

      for (final knowledgeState in CellKnowledgeState.values) {
        expect(
          FogRenderer.animatesFog(_state(knowledgeState)),
          isFalse,
          reason: '${knowledgeState.name} must remain static',
        );
      }

      final compositedLuminance = [
        for (final fill in fills)
          Color.alphaBlend(fill, const Color(0xFFB0B0B0)).computeLuminance(),
      ];
      for (var i = 1; i < compositedLuminance.length; i++) {
        expect(
          compositedLuminance[i],
          lessThan(compositedLuminance[i - 1]),
          reason: 'Each state must conceal more grayscale map contrast.',
        );
      }
    });

    test('frontier shroud previews map context without becoming knowledge', () {
      final frontier = CellState(
        knowledgeState: CellKnowledgeState.shrouded,
        relationship: CellRelationship.frontier,
        contents: CellContents.empty,
      );
      final unknown = CellState(
        knowledgeState: CellKnowledgeState.shrouded,
        relationship: CellRelationship.unknown,
        contents: CellContents.empty,
      );

      expect(frontier.knowledgeState, CellKnowledgeState.shrouded);
      expect(FogRenderer.fillColor(frontier).a, lessThan(1));
      expect(
        FogRenderer.fillColor(frontier).a,
        greaterThan(
          FogRenderer.fillColor(_state(CellKnowledgeState.informed)).a,
        ),
      );
      expect(FogRenderer.fillColor(unknown).a, 1);
      expect(FogRenderer.strokeColor(frontier).a, greaterThan(0));
    });

    test(
      'Informed is visibly distinct from Explored without changing seams',
      () {
        final informed = _state(CellKnowledgeState.informed, category: 'fauna');
        final explored = _state(CellKnowledgeState.explored);

        expect(
          FogRenderer.fillColor(informed),
          isNot(FogRenderer.fillColor(explored)),
        );
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
      },
    );

    test('category cue survives light, mid, and dark grayscale surfaces', () {
      for (final background in const [
        Color(0xFFE8E8E8),
        Color(0xFF808080),
        Color(0xFF1B1B1B),
      ]) {
        final underlayContrast = _contrastRatio(
          background,
          FogRenderer.categoryCueUnderlayColor,
        );
        final outlineContrast = _contrastRatio(
          background,
          FogRenderer.categoryCueOutlineColor,
        );
        expect(
          underlayContrast >= 3 || outlineContrast >= 3,
          isTrue,
          reason: 'The cue boundary must survive every grayscale surface.',
        );
      }
      expect(
        _contrastRatio(
          FogRenderer.categoryCueUnderlayColor,
          FogRenderer.categoryCueColor,
        ),
        greaterThanOrEqualTo(7),
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

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance < secondLuminance
      ? firstLuminance
      : secondLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
