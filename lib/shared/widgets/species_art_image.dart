import 'package:flutter/material.dart';

/// Displays species artwork from a URL, falling back to an emoji icon.
///
/// Used in discovery toasts, species cards, and the collection viewer.
class SpeciesArtImage extends StatelessWidget {
  /// Remote art/icon URL. When null or empty, [fallbackEmoji] is shown.
  final String? artUrl;

  /// Emoji or text rendered when no [artUrl] is available.
  final String fallbackEmoji;

  /// Bounding box size for the image container.
  final double size;

  /// Border radius applied to the image. Defaults to circular (round).
  final BorderRadius? borderRadius;

  const SpeciesArtImage({
    super.key,
    this.artUrl,
    this.fallbackEmoji = '❓',
    required this.size,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size / 2);

    final url = artUrl;
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback(size),
        ),
      );
    }

    return _fallback(size);
  }

  Widget _fallback(double size) {
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
}
