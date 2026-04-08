import 'package:flutter/material.dart';
import 'package:earth_nova/shared/theme/app_theme.dart';

class PinchHint extends StatelessWidget {
  const PinchHint({
    super.key,
    required this.lowerLevelLabel,
    required this.upperLevelLabel,
  });

  final String lowerLevelLabel;
  final String? upperLevelLabel;

  @override
  Widget build(BuildContext context) {
    final text = upperLevelLabel != null
        ? '↙ $lowerLevelLabel · Pinch out → $upperLevelLabel ↗'
        : '↙ Pinch in → $lowerLevelLabel';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xD20D1B2A),
        border: Border.all(
          color: AppTheme.outline,
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
    );
  }
}
