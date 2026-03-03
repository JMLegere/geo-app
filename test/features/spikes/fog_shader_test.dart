import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/features/spikes/fog_math.dart';

void main() {
  group('FogMath.calculateFogAlpha', () {
    const playerPos = Offset(200, 400);
    const revealRadius = 150.0;

    // ------------------------------------------------------------------
    // 1. Fragment at player position → fully clear (alpha ≈ 0.0)
    // ------------------------------------------------------------------
    test('fragment at player position is fully clear', () {
      final alpha = FogMath.calculateFogAlpha(
        fragPosition: playerPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 1.0,
      );
      expect(alpha, closeTo(0.0, 1e-9));
    });

    // ------------------------------------------------------------------
    // 2. Fragment well outside reveal radius → max fog (alpha ≈ 0.85)
    // ------------------------------------------------------------------
    test('fragment well outside reveal radius is fully fogged', () {
      // 3× the radius ensures we are well into the plateau (smoothstep = 1.0)
      final fragPos = playerPos + const Offset(revealRadius * 3, 0);
      final alpha = FogMath.calculateFogAlpha(
        fragPosition: fragPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 1.0,
      );
      expect(alpha, closeTo(0.85, 1e-9));
    });

    // ------------------------------------------------------------------
    // 3. Fragment at reveal radius edge → in transition zone (0 < α < 0.85)
    // ------------------------------------------------------------------
    test('fragment at reveal radius edge is in transition zone', () {
      // At dist == revealRadius, smoothstep returns 1.0 → alpha = 0.85.
      // Just inside (0.85× radius) should be between 0 and 0.85.
      final fragPos = playerPos + Offset(revealRadius * 0.85, 0);
      final alpha = FogMath.calculateFogAlpha(
        fragPosition: fragPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 1.0,
      );
      expect(alpha, greaterThan(0.0));
      expect(alpha, lessThan(0.85));
    });

    // ------------------------------------------------------------------
    // 4. Fragment at inner radius boundary (0.7 × revealRadius) → clear (α ≈ 0.0)
    // ------------------------------------------------------------------
    test('fragment at inner radius boundary is clear', () {
      final fragPos = playerPos + Offset(revealRadius * 0.7, 0);
      final alpha = FogMath.calculateFogAlpha(
        fragPosition: fragPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 1.0,
      );
      expect(alpha, closeTo(0.0, 1e-9));
    });

    // ------------------------------------------------------------------
    // 5. fogDensity = 0.0 → fog alpha = 0.0 everywhere
    // ------------------------------------------------------------------
    test('fogDensity 0.0 produces zero alpha everywhere', () {
      for (final dist in [0.0, 75.0, 150.0, 300.0]) {
        final fragPos = playerPos + Offset(dist, 0);
        final alpha = FogMath.calculateFogAlpha(
          fragPosition: fragPos,
          playerPosition: playerPos,
          revealRadius: revealRadius,
          fogDensity: 0.0,
        );
        expect(alpha, closeTo(0.0, 1e-9),
            reason: 'expected 0.0 at dist=$dist with fogDensity=0');
      }
    });

    // ------------------------------------------------------------------
    // 6. fogDensity = 0.5 → alpha is halved compared to fogDensity = 1.0
    // ------------------------------------------------------------------
    test('fogDensity 0.5 produces half the alpha of fogDensity 1.0', () {
      final farPos = playerPos + Offset(revealRadius * 3, 0);
      final fullAlpha = FogMath.calculateFogAlpha(
        fragPosition: farPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 1.0,
      );
      final halfAlpha = FogMath.calculateFogAlpha(
        fragPosition: farPos,
        playerPosition: playerPos,
        revealRadius: revealRadius,
        fogDensity: 0.5,
      );
      expect(halfAlpha, closeTo(fullAlpha * 0.5, 1e-9));
    });

    // ------------------------------------------------------------------
    // 7. revealRadius = 0 → everything at non-zero distance is fogged
    // ------------------------------------------------------------------
    test('revealRadius 0 produces max fog beyond player position', () {
      // With zero radius the degenerate smoothstep clamps to 1.0 for any
      // positive distance, giving alpha = 1.0 * fogDensity * 0.85.
      final farPos = playerPos + const Offset(1, 0);
      final alpha = FogMath.calculateFogAlpha(
        fragPosition: farPos,
        playerPosition: playerPos,
        revealRadius: 0,
        fogDensity: 1.0,
      );
      expect(alpha, closeTo(0.85, 1e-9));
    });

    // ------------------------------------------------------------------
    // 8. Symmetry: same distance in different directions → same alpha
    // ------------------------------------------------------------------
    test('symmetry: equal distances in any direction produce equal alpha', () {
      final directions = [
        const Offset(1, 0),
        const Offset(0, 1),
        const Offset(-1, 0),
        const Offset(0, -1),
        Offset(1 / _sqrt2, 1 / _sqrt2),
        Offset(-1 / _sqrt2, 1 / _sqrt2),
      ];
      const testDist = 120.0; // inside transition zone

      final alphas = directions.map((dir) {
        final fragPos = playerPos + dir * testDist;
        return FogMath.calculateFogAlpha(
          fragPosition: fragPos,
          playerPosition: playerPos,
          revealRadius: revealRadius,
          fogDensity: 1.0,
        );
      }).toList();

      final reference = alphas.first;
      for (final alpha in alphas) {
        expect(alpha, closeTo(reference, 1e-9));
      }
    });

    // ------------------------------------------------------------------
    // 9. smoothstep values at known points
    // ------------------------------------------------------------------
    group('FogMath.smoothstep', () {
      test('returns 0.0 at edge0 (t=0)', () {
        expect(FogMath.smoothstep(0.0, 1.0, 0.0), closeTo(0.0, 1e-9));
      });

      test('returns 1.0 at edge1 (t=1)', () {
        expect(FogMath.smoothstep(0.0, 1.0, 1.0), closeTo(1.0, 1e-9));
      });

      test('returns 0.5 at t=0.5 (symmetric midpoint)', () {
        // smoothstep(0.5) = 0.5² * (3 - 2*0.5) = 0.25 * 2 = 0.5
        expect(FogMath.smoothstep(0.0, 1.0, 0.5), closeTo(0.5, 1e-9));
      });

      test('returns 0.0 for x < edge0 (clamp left)', () {
        expect(FogMath.smoothstep(0.3, 0.7, 0.1), closeTo(0.0, 1e-9));
      });

      test('returns 1.0 for x > edge1 (clamp right)', () {
        expect(FogMath.smoothstep(0.3, 0.7, 0.9), closeTo(1.0, 1e-9));
      });

      test('t=0.25 gives correct cubic Hermite value', () {
        // t=0.25 → 0.0625 * (3 - 0.5) = 0.0625 * 2.5 = 0.15625
        expect(FogMath.smoothstep(0.0, 1.0, 0.25), closeTo(0.15625, 1e-9));
      });

      test('t=0.75 gives correct cubic Hermite value', () {
        // t=0.75 → 0.5625 * (3 - 1.5) = 0.5625 * 1.5 = 0.84375
        expect(FogMath.smoothstep(0.0, 1.0, 0.75), closeTo(0.84375, 1e-9));
      });
    });
  });
}

const double _sqrt2 = 1.4142135623730951;
