import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/domain/entities/iucn_status.dart';
import 'package:earth_nova/shared/extensions/iucn_status_theme.dart';

void main() {
  group('IucnStatusTheme extension', () {
    test('every IucnStatus has a non-null color', () {
      for (final status in IucnStatus.values) {
        expect(status.color, isNotNull,
            reason: '${status.name} has null color');
      }
    });

    test('every IucnStatus has a non-null fgColor', () {
      for (final status in IucnStatus.values) {
        expect(status.fgColor, isNotNull,
            reason: '${status.name} has null fgColor');
      }
    });

    test('every IucnStatus has borderAlpha in [0.0, 1.0]', () {
      for (final status in IucnStatus.values) {
        expect(status.borderAlpha, inInclusiveRange(0.0, 1.0),
            reason: '${status.name} borderAlpha out of range');
      }
    });

    test('every IucnStatus has glowAlpha in [0.0, 1.0]', () {
      for (final status in IucnStatus.values) {
        expect(status.glowAlpha, inInclusiveRange(0.0, 1.0),
            reason: '${status.name} glowAlpha out of range');
      }
    });

    test('criticallyEndangered color is purple', () {
      expect(IucnStatus.criticallyEndangered.color, const Color(0xFF9C27B0));
    });

    test('leastConcern color is gray', () {
      expect(IucnStatus.leastConcern.color, const Color(0xFFCDD5DB));
    });

    test('endangered color is gold', () {
      expect(IucnStatus.endangered.color, const Color(0xFFFFD700));
    });

    test('leastConcern fgColor is dark', () {
      expect(IucnStatus.leastConcern.fgColor, const Color(0xFF1A1A2E));
    });

    test('criticallyEndangered fgColor is white', () {
      expect(IucnStatus.criticallyEndangered.fgColor, Colors.white);
    });
  });
}
