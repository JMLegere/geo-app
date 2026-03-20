import 'package:flutter/material.dart' hide Durations;

import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/game_icons.dart';

/// Animated RGB stat bars for the species card.
///
/// Three horizontal bars (brawn/wit/speed) with colors derived from stat
/// values. Bars animate in with staggered timing on card entrance.
class SpeciesCardStats extends StatelessWidget {
  const SpeciesCardStats({
    required this.brawn,
    required this.wit,
    required this.speed,
    this.animate = true,
    super.key,
  });

  final int brawn;
  final int wit;
  final int speed;
  final bool animate;

  static const int _maxStat = 90;

  Color _brawnColor(int v) =>
      Color.fromRGBO((v / _maxStat * 255).round().clamp(0, 255), 60, 60, 1.0);

  Color _witColor(int v) =>
      Color.fromRGBO(60, 60, (v / _maxStat * 255).round().clamp(0, 255), 1.0);

  Color _speedColor(int v) =>
      Color.fromRGBO(60, (v / _maxStat * 255).round().clamp(0, 255), 60, 1.0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        _StatBarRow(
          icon: GameIcons.brawn,
          value: brawn,
          color: _brawnColor(brawn),
          animate: animate,
          delayMs: 0,
          maxStat: _maxStat,
          surfaceColor: cs.surfaceContainerHighest,
        ),
        SizedBox(height: Spacing.xs),
        _StatBarRow(
          icon: GameIcons.wit,
          value: wit,
          color: _witColor(wit),
          animate: animate,
          delayMs: 80,
          maxStat: _maxStat,
          surfaceColor: cs.surfaceContainerHighest,
        ),
        SizedBox(height: Spacing.xs),
        _StatBarRow(
          icon: GameIcons.speed,
          value: speed,
          color: _speedColor(speed),
          animate: animate,
          delayMs: 160,
          maxStat: _maxStat,
          surfaceColor: cs.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _StatBarRow extends StatefulWidget {
  const _StatBarRow({
    required this.icon,
    required this.value,
    required this.color,
    required this.animate,
    required this.delayMs,
    required this.maxStat,
    required this.surfaceColor,
  });

  final String icon;
  final int value;
  final Color color;
  final bool animate;
  final int delayMs;
  final int maxStat;
  final Color surfaceColor;

  @override
  State<_StatBarRow> createState() => _StatBarRowState();
}

class _StatBarRowState extends State<_StatBarRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    if (widget.animate) {
      Future.delayed(Duration(milliseconds: 200 + widget.delayMs), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fraction = (widget.value / widget.maxStat).clamp(0.0, 1.0);

    return Row(
      children: [
        Text(widget.icon, style: const TextStyle(fontSize: 14)),
        SizedBox(width: Spacing.xs),
        Expanded(
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: Radii.borderSm,
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 6,
                      color: widget.surfaceColor,
                    ),
                    // Filled portion
                    FractionallySizedBox(
                      widthFactor: fraction * _animation.value,
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: widget.color,
                          borderRadius: Radii.borderSm,
                          boxShadow: [
                            BoxShadow(
                              color: widget.color.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        SizedBox(width: Spacing.xs),
        SizedBox(
          width: 28,
          child: Text(
            '${widget.value}',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
