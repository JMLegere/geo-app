import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/player_provider.dart';

/// Top status bar showing key exploration stats (Apple Maps style).
///
/// Reads [playerProvider] for live stats:
/// - 🔍 Cells observed
/// - 🚶 Distance walked in km
/// - 🔥 Current exploration streak in days
///
/// Uses a translucent frosted-glass background (BackdropFilter + ClipRect)
/// and respects the device's safe area (status bar height).
///
/// ## Usage
///
/// ```dart
/// Positioned(
///   top: 0, left: 0, right: 0,
///   child: const StatusBar(),
/// )
/// ```
class StatusBar extends ConsumerWidget {
  const StatusBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _StatPill(
                emoji: '🔍',
                value: '${player.cellsObserved} cells',
              ),
              _StatPill(
                emoji: '🚶',
                value: '${player.totalDistanceKm.toStringAsFixed(1)} km',
              ),
              _StatPill(
                emoji: '🔥',
                value: '${player.currentStreak} days',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact stat chip with an emoji label and a formatted value.
class _StatPill extends StatelessWidget {
  final String emoji;
  final String value;

  const _StatPill({required this.emoji, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$emoji $value',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A2E),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
