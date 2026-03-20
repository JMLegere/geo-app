import 'package:flutter/material.dart';

/// Displays species art from a network URL, falling back to an emoji.
///
/// Used across all UI surfaces: pack grid, discovery toast, sanctuary tile,
/// and species card modal. Handles loading, error, and missing URL states
/// gracefully — shows the emoji immediately, replaces with art when loaded.
class SpeciesArtImage extends StatelessWidget {
  const SpeciesArtImage({
    required this.fallbackEmoji,
    required this.size,
    this.artUrl,
    this.borderRadius,
    super.key,
  });

  /// Network URL for the art asset. Null = show fallback.
  final String? artUrl;

  /// Emoji to display when art is unavailable or loading.
  final String fallbackEmoji;

  /// Display size (width and height) in logical pixels.
  final double size;

  /// Optional border radius for clipping the image.
  final BorderRadius? borderRadius;

  Widget _buildEmojiFallback() {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          fallbackEmoji,
          style: TextStyle(fontSize: size * 0.55),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (artUrl == null) {
      content = _buildEmojiFallback();
    } else {
      final networkImage = Image.network(
        artUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          return AnimatedOpacity(
            opacity: frame != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildEmojiFallback(),
      );

      content = Stack(
        children: [
          _buildEmojiFallback(),
          networkImage,
        ],
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
