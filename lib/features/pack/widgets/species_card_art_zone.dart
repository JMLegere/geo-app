import 'dart:math' as math;

import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/animal_class.dart';
import 'package:earth_nova/core/models/animal_type.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';
import 'package:earth_nova/shared/habitat_colors.dart';
import 'package:earth_nova/shared/widgets/species_art_image.dart';

// Art zone widget — used by SpeciesCard.
/// Renders the 512x512 watercolor illustration on a habitat-colored surface
/// with vignette edges. Falls back to the animal-class emoji with a shimmer
/// overlay when art is unavailable or loading.
class SpeciesCardArtZone extends StatelessWidget {
  const SpeciesCardArtZone({
    required this.artUrl,
    required this.primaryHabitat,
    required this.habitats,
    required this.definitionId,
    this.animalClass,
    this.animalType,
    super.key,
  });

  /// Network URL for the 512×512 watercolor illustration.
  final String? artUrl;

  /// Primary habitat for the card background color.
  final Habitat primaryHabitat;

  /// All habitats (for marbling effect when 2+).
  final List<Habitat> habitats;

  /// Used to seed the marbling pattern for multi-habitat species.
  final String definitionId;

  /// Shown as fallback emoji in the art zone.
  final AnimalClass? animalClass;

  /// Shown as fallback emoji for unenriched species.
  final AnimalType? animalType;

  String get _fallbackEmoji {
    if (animalClass != null) return GameIcons.animalClass(animalClass!);
    if (animalType != null) return GameIcons.animalType(animalType!);
    return '🐾';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: Radii.borderMd,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Habitat background (solid or marbled) ───────────────────────
          _HabitatBackground(
            habitats: habitats,
            primaryHabitat: primaryHabitat,
            definitionId: definitionId,
          ),

          // ── Illustration ────────────────────────────────────────────────
          if (artUrl != null)
            SpeciesArtImage(
              artUrl: artUrl,
              fallbackEmoji: _fallbackEmoji,
              size: 512,
            )
          else
            // No-art fallback: centered emoji with shimmer
            _NoArtFallback(emoji: _fallbackEmoji),

          // ── Vignette overlay ────────────────────────────────────────────
          const _VignetteOverlay(),
        ],
      ),
    );
  }
}

/// Habitat-colored background — solid gradient or marbled for multi-habitat.
class _HabitatBackground extends StatelessWidget {
  const _HabitatBackground({
    required this.habitats,
    required this.primaryHabitat,
    required this.definitionId,
  });

  final List<Habitat> habitats;
  final Habitat primaryHabitat;
  final String definitionId;

  @override
  Widget build(BuildContext context) {
    if (habitats.length >= 2) {
      return CustomPaint(
        painter: _MarblingPainter(
          habitats: habitats,
          seed: definitionId.hashCode,
        ),
        child: Container(),
      );
    }

    final palette = HabitatColors.of(primaryHabitat);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.primary,
            palette.secondary,
          ],
        ),
      ),
    );
  }
}

/// Seeded marbling effect for multi-habitat species.
/// Two or three habitat-colored oval blobs, each clipped and blended.
class _MarblingPainter extends CustomPainter {
  const _MarblingPainter({required this.habitats, required this.seed});

  final List<Habitat> habitats;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    // Base: darkest habitat's primary
    final basePalette = HabitatColors.of(habitats.first);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = basePalette.primary,
    );

    // Deterministic RNG seeded by definitionId
    final rng = math.Random(seed);

    for (int i = 0; i < habitats.length && i < 3; i++) {
      final palette = HabitatColors.of(habitats[i]);
      // Random oval blob position and size
      final cx = rng.nextDouble() * size.width;
      final cy = rng.nextDouble() * size.height;
      final rx = size.width * (0.3 + rng.nextDouble() * 0.4);
      final ry = size.height * (0.3 + rng.nextDouble() * 0.4);

      final rect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx,
        height: ry,
      );

      final paint = Paint()
        ..color = palette.primary.withValues(alpha: 0.35)
        ..blendMode = BlendMode.srcOver;

      canvas.drawOval(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_MarblingPainter old) =>
      old.seed != seed || old.habitats != habitats;
}

/// Radial vignette overlay — transparent center, dark edges.
class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.45),
            ],
            stops: const [0.4, 1.0],
            center: Alignment.center,
            radius: 0.85,
          ),
        ),
      ),
    );
  }
}

/// No-art fallback: centered emoji + shimmer sweep.
class _NoArtFallback extends StatefulWidget {
  const _NoArtFallback({required this.emoji});

  final String emoji;

  @override
  State<_NoArtFallback> createState() => _NoArtFallbackState();
}

class _NoArtFallbackState extends State<_NoArtFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Shimmer sweep
        AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) {
            return ShaderMask(
              shaderCallback: (bounds) {
                final t = _shimmer.value;
                return LinearGradient(
                  begin: Alignment(-1.0 + 2.0 * t, -1),
                  end: Alignment(-0.5 + 2.0 * t, 1),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.12),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Container(color: Colors.white),
            );
          },
        ),
        // Centered emoji
        Center(
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 48),
          ),
        ),
      ],
    );
  }
}
