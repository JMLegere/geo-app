import 'package:flutter/material.dart';

/// Compact progress indicator showing how many species the player has collected.
///
/// Displays "X / Y collected" label above a [LinearProgressIndicator].
/// Used at the top of JournalScreen below the AppBar.
class JournalProgressBar extends StatelessWidget {
  final int collected;
  final int total;

  const JournalProgressBar({
    super.key,
    required this.collected,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? collected / total : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$collected / $total collected',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A2E),
                  letterSpacing: -0.1,
                ),
              ),
              Text(
                total > 0
                    ? '${(fraction * 100).round()}%'
                    : '0%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
