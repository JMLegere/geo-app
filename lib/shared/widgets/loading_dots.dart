import 'package:flutter/material.dart';
import 'package:earth_nova/shared/theme/design_tokens.dart' as tokens;

/// Animated spinning-world indicator: cycles through 🌍 🌎 🌏.
class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key});

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _frameIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: tokens.Durations.loadingCycle,
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _frameIndex = (_frameIndex + 1) % _earthFrames.length);
          _controller.forward(from: 0);
        }
      });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: ExcludeSemantics(
        child: Text(
          _earthFrames[_frameIndex],
          style: const TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}

const _earthFrames = ['🌍', '🌎', '🌏'];
