import 'dart:ui' show Offset;

/// Pure Dart fog math — mirrors the GLSL logic in shaders/fog.frag.
///
/// Kept separate from the shader painter so it can be unit-tested
/// without a GPU context.
class FogMath {
  FogMath._();

  /// Calculates fog alpha at [fragPosition] given player position, reveal
  /// radius, and fog density.
  ///
  /// Replicates the GLSL smoothstep from fog.frag:
  /// ```glsl
  /// float fog = smoothstep(revealRadius * 0.7, revealRadius, dist);
  /// fog *= fogDensity;
  /// fragColor = vec4(0.1, 0.1, 0.15, fog * 0.85);
  /// ```
  static double calculateFogAlpha({
    required Offset fragPosition,
    required Offset playerPosition,
    required double revealRadius,
    required double fogDensity,
  }) {
    final dist = (fragPosition - playerPosition).distance;
    final innerRadius = revealRadius * 0.7;

    // Replicate GLSL smoothstep(edge0, edge1, x)
    // Returns 0.0 if x <= edge0, 1.0 if x >= edge1, smooth curve between.
    final fog = _smoothstep(innerRadius, revealRadius, dist);
    return fog * fogDensity * 0.85;
  }

  /// GLSL smoothstep equivalent.
  ///
  /// Returns 0.0 when [x] <= [edge0], 1.0 when [x] >= [edge1], and a
  /// cubic Hermite interpolation in between.
  static double smoothstep(double edge0, double edge1, double x) =>
      _smoothstep(edge0, edge1, x);

  static double _smoothstep(double edge0, double edge1, double x) {
    if (edge1 == edge0) {
      // Degenerate case: zero-width transition — clamp based on which side.
      return x < edge0 ? 0.0 : 1.0;
    }
    final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
  }
}
