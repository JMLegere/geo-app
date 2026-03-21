import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/shared/design_tokens.dart';

/// Displays species art from a network URL, falling back to an emoji.
///
/// Used across all UI surfaces: pack grid, discovery toast, sanctuary tile,
/// and species card modal. Handles loading, error, and missing URL states
/// gracefully — shows the emoji immediately, replaces with art when loaded.
///
/// When [animate] is true and [artUrl] is non-null, a subtle sinusoidal
/// breathing idle animation plays (scale-Y + translate-Y, anchored at
/// bottom-center so the sprite's feet stay grounded). Use [animationSeed]
/// to phase-offset each sprite so they don't breathe in sync.
class SpeciesArtImage extends StatefulWidget {
  const SpeciesArtImage({
    required this.fallbackEmoji,
    required this.size,
    this.artUrl,
    this.borderRadius,
    this.animate = false,
    this.animationSeed = 0,
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

  /// Whether to play the idle breathing animation.
  final bool animate;

  /// Seed for phase-offsetting the animation so sprites don't breathe in sync.
  final int animationSeed;

  @override
  State<SpeciesArtImage> createState() => _SpeciesArtImageState();
}

class _SpeciesArtImageState extends State<SpeciesArtImage>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  bool get _shouldAnimate => widget.animate && widget.artUrl != null;

  @override
  void initState() {
    super.initState();
    _maybeCreateController();
  }

  @override
  void didUpdateWidget(SpeciesArtImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate != (oldWidget.animate && oldWidget.artUrl != null)) {
      _maybeCreateController();
    }
  }

  void _maybeCreateController() {
    if (_shouldAnimate && _controller == null) {
      _controller = AnimationController(
        vsync: this,
        duration: Durations.spriteIdle,
      )..repeat();
    } else if (!_shouldAnimate && _controller != null) {
      _controller!.dispose();
      _controller = null;
    }
  }

  @override
  void deactivate() {
    if (widget.artUrl != null && kIsWeb) {
      // ignore: avoid_print
      print('[ART UNLOAD] ${widget.artUrl!.split('/').last} deactivated');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _controller?.dispose();
    if (widget.artUrl != null) {
      print('[ART] disposed ${_shortUrl(widget.artUrl!)}');
    }
    super.dispose();
  }

  static String _shortUrl(String url) {
    // Show just the filename for readable logs
    final lastSlash = url.lastIndexOf('/');
    return lastSlash >= 0 ? url.substring(lastSlash + 1) : url;
  }

  Widget _buildEmojiFallback() {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: Text(
          widget.fallbackEmoji,
          style: TextStyle(fontSize: widget.size * 0.55),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (widget.artUrl == null) {
      content = _buildEmojiFallback();
    } else {
      final shortName = _shortUrl(widget.artUrl!);
      final networkImage = Image.network(
        widget.artUrl!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (frame != null && !wasSynchronouslyLoaded) {
            print('[ART] loaded $shortName (network fetch — cache miss)');
          }
          return AnimatedOpacity(
            opacity: frame != null ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('[ART FAIL] image load error for ${widget.artUrl}: $error');
          return _buildEmojiFallback();
        },
      );

      content = Stack(
        children: [
          _buildEmojiFallback(),
          networkImage,
        ],
      );
    }

    // Wrap in breathing animation when active.
    if (_shouldAnimate && _controller != null) {
      final phaseOffset =
          (widget.animationSeed.hashCode & 0xFFFF) / 0xFFFF;
      content = RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller!,
          builder: (context, child) {
            final t = (_controller!.value + phaseOffset) % 1.0;
            final sin = math.sin(t * 2 * math.pi);
            final scaleY = 1.0 - 0.05 * sin;
            final translateY = widget.size * 0.02 * sin;
            return Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.identity()
                ..scale(1.0, scaleY)
                ..translate(0.0, translateY),
              child: child,
            );
          },
          child: content,
        ),
      );
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: content,
      );
    }

    return content;
  }
}
