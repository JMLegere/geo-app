#include <flutter/runtime_effect.glsl>

// Uniforms (passed via setFloat in order):
// 0: uViewportWidth
// 1: uViewportHeight
// 2: uPlayerScreenX (player position in screen pixels)
// 3: uPlayerScreenY
// 4: uRevealRadius (radius of clear region in pixels)
// 5: uFogDensity (0.0 = fully clear, 1.0 = fully opaque)

uniform float uViewportWidth;
uniform float uViewportHeight;
uniform float uPlayerScreenX;
uniform float uPlayerScreenY;
uniform float uRevealRadius;
uniform float uFogDensity;

out vec4 fragColor;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 playerPos = vec2(uPlayerScreenX, uPlayerScreenY);
  float revealRadius = uRevealRadius;
  float fogDensity = uFogDensity;

  // Distance from current fragment to player position
  float dist = length(fragCoord - playerPos);

  // smoothstep: fully clear inside (revealRadius * 0.7), fully fogged outside revealRadius
  float fog = smoothstep(revealRadius * 0.7, revealRadius, dist);

  // Apply fog density
  fog *= fogDensity;

  // Dark fog color with alpha
  fragColor = vec4(0.1, 0.1, 0.15, fog * 0.85);
}
