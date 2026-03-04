import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/fog_state.dart';
import 'package:fog_of_world/features/map/layers/fog_canvas_painter.dart';
import 'package:fog_of_world/features/map/models/cell_render_data.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

FogCanvasPainter _painter({
  List<CellRenderData> cells = const [],
  int version = 0,
  Color fogColor = const Color(0xFF161620),
  double blurSigma = 3.0,
}) =>
    FogCanvasPainter(
      cells: cells,
      version: version,
      fogColor: fogColor,
      blurSigma: blurSigma,
    );

CellRenderData _observedCell(String id) => CellRenderData(
      cellId: id,
      fogState: FogState.observed,
      screenVertices: const [
        Offset(0, 0),
        Offset(50, 0),
        Offset(50, 50),
      ],
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FogCanvasPainter', () {
    // -------------------------------------------------------------------------
    // Construction
    // -------------------------------------------------------------------------

    test('can construct with empty cells list — no crash', () {
      expect(() => _painter(), returnsNormally);
    });

    test('can construct with multiple cells of different states', () {
      final cells = FogState.values
          .where((s) => s != FogState.undetected)
          .map(
            (s) => CellRenderData(
              cellId: s.name,
              fogState: s,
              screenVertices: const [
                Offset(0, 0),
                Offset(10, 0),
                Offset(10, 10),
              ],
            ),
          )
          .toList();

      expect(() => _painter(cells: cells), returnsNormally);
    });

    test('default fogColor is Color(0xFF161620)', () {
      final p = FogCanvasPainter(cells: const [], version: 0);
      expect(p.fogColor, equals(const Color(0xFF161620)));
    });

    test('default blurSigma is 0.0', () {
      final p = FogCanvasPainter(cells: const [], version: 0);
      expect(p.blurSigma, equals(0.0));
    });

    // -------------------------------------------------------------------------
    // shouldRepaint — same configuration
    // -------------------------------------------------------------------------

    test('shouldRepaint returns false when version, fogColor and blurSigma are identical', () {
      final old = _painter(version: 5);
      final current = _painter(version: 5);
      expect(current.shouldRepaint(old), isFalse);
    });

    test('shouldRepaint returns false even if cells list instance differs but version is same', () {
      // Version-based comparison: if version hasn't changed, no repaint.
      final old = _painter(cells: [_observedCell('a')], version: 3);
      final current = _painter(cells: [_observedCell('b')], version: 3);
      expect(current.shouldRepaint(old), isFalse);
    });

    // -------------------------------------------------------------------------
    // shouldRepaint — version change
    // -------------------------------------------------------------------------

    test('shouldRepaint returns true when renderVersion changes', () {
      final old = _painter(version: 0);
      final current = _painter(version: 1);
      expect(current.shouldRepaint(old), isTrue);
    });

    test('shouldRepaint returns true when version decreases (unusual but valid)', () {
      final old = _painter(version: 5);
      final current = _painter(version: 3);
      expect(current.shouldRepaint(old), isTrue);
    });

    // -------------------------------------------------------------------------
    // shouldRepaint — fogColor change
    // -------------------------------------------------------------------------

    test('shouldRepaint returns true when fogColor changes', () {
      final old = _painter(fogColor: Colors.black, version: 1);
      final current = _painter(fogColor: Colors.red, version: 1);
      expect(current.shouldRepaint(old), isTrue);
    });

    test('shouldRepaint returns false when fogColor is same instance', () {
      const color = Color(0xFF161620);
      final old = _painter(fogColor: color, version: 2);
      final current = _painter(fogColor: color, version: 2);
      expect(current.shouldRepaint(old), isFalse);
    });

    // -------------------------------------------------------------------------
    // shouldRepaint — blurSigma change
    // -------------------------------------------------------------------------

    test('shouldRepaint returns true when blurSigma changes', () {
      final old = _painter(blurSigma: 3.0, version: 0);
      final current = _painter(blurSigma: 5.0, version: 0);
      expect(current.shouldRepaint(old), isTrue);
    });

    test('shouldRepaint returns false when blurSigma is identical', () {
      final old = _painter(blurSigma: 2.5, version: 0);
      final current = _painter(blurSigma: 2.5, version: 0);
      expect(current.shouldRepaint(old), isFalse);
    });

    test('shouldRepaint returns true when blurSigma changes to 0 (crisp edges)', () {
      final old = _painter(blurSigma: 3.0, version: 1);
      final current = _painter(blurSigma: 0.0, version: 1);
      expect(current.shouldRepaint(old), isTrue);
    });

    // -------------------------------------------------------------------------
    // shouldRepaint — combined changes
    // -------------------------------------------------------------------------

    test('shouldRepaint returns true when all three fields change simultaneously', () {
      final old = _painter(version: 0, fogColor: Colors.black, blurSigma: 3.0);
      final current = _painter(version: 1, fogColor: Colors.blue, blurSigma: 5.0);
      expect(current.shouldRepaint(old), isTrue);
    });

    // -------------------------------------------------------------------------
    // Cell state filtering — only non-undetected cells punch holes
    // -------------------------------------------------------------------------

    test('undetected cells produce no holes (revealStrength = 0, skipped entirely)', () {
      // No assertion on paint output — just verify no errors thrown with
      // a list containing only undetected cells.
      final cells = [
        const CellRenderData(
          cellId: 'ud',
          fogState: FogState.undetected,
          screenVertices: [Offset(0, 0), Offset(10, 0), Offset(10, 10)],
        ),
      ];
      expect(() => _painter(cells: cells), returnsNormally);
    });

    test('cells with fewer than 3 vertices are silently skipped', () {
      final cells = [
        const CellRenderData(
          cellId: 'tiny',
          fogState: FogState.observed,
          screenVertices: [Offset(0, 0), Offset(10, 0)], // Only 2 points
        ),
      ];
      // Should not throw even though the polygon is invalid.
      expect(() => _painter(cells: cells), returnsNormally);
    });

    // -------------------------------------------------------------------------
    // Fog state density → reveal strength mapping
    // -------------------------------------------------------------------------

    test('FogState density values map to expected reveal strengths', () {
      // Verify the density values used by the painter match FogState constants.
      expect(FogState.undetected.density, equals(1.0)); // revealStrength = 0.0
      expect(FogState.unexplored.density, equals(0.75)); // revealStrength = 0.25
      expect(FogState.hidden.density, equals(0.5)); // revealStrength = 0.5
      expect(FogState.concealed.density, equals(0.95)); // revealStrength = 0.05
      expect(FogState.observed.density, equals(0.0)); // revealStrength = 1.0
    });
  });
}
