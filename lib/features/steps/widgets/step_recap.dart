import 'package:flutter/material.dart' hide Durations, StepState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:earth_nova/features/steps/providers/step_provider.dart';
import 'package:earth_nova/shared/design_tokens.dart';
import 'package:earth_nova/shared/earth_nova_theme.dart';
import 'package:earth_nova/shared/widgets/frosted_glass_container.dart';

/// Duration of the count-up animation (0 → loginDelta).
const _kCountUpDuration = Duration(milliseconds: 1500);

/// Overlay that plays a count-up animation showing steps gained while the
/// app was closed.
///
/// Watches [StepState.isAnimating] and [StepState.loginDelta]. Animates
/// automatically when [StepState.isAnimating] is `true` and
/// [StepState.loginDelta] is greater than zero. Calls
/// [StepNotifier.markAnimationComplete] after the count-up finishes, which
/// resets [StepState.isAnimating] to false.
///
/// Does not show on web — [StepState.loginDelta] is always 0 there
/// (no pedometer), so the guard prevents the overlay from ever rendering.
///
/// ## Usage
///
/// Embed in a [Stack] in `MapScreen` (or any top-level overlay):
///
/// ```dart
/// const Align(
///   alignment: Alignment(0, 0.45),
///   child: IgnorePointer(child: StepRecap()),
/// )
/// ```
///
/// The widget returns [SizedBox.shrink] when no animation is playing, so it
/// takes no space in the layout.
class StepRecap extends ConsumerStatefulWidget {
  const StepRecap({super.key});

  @override
  ConsumerState<StepRecap> createState() => _StepRecapState();
}

class _StepRecapState extends ConsumerState<StepRecap>
    with SingleTickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: Durations.slow, // 350 ms
    );

    _scaleAnimation = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: AppCurves.bounce),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: AppCurves.fadeIn),
    );

    // Trigger entry animation if the flag is already set when the widget
    // first mounts (e.g. stepProvider hydrated before MapScreen built).
    final initial = ref.read(stepProvider);
    if (initial.isAnimating && initial.loginDelta > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startEntry();
      });
    }
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _startEntry() {
    _entryController.forward(from: 0);
  }

  /// Called by [_RecapCard] when the count-up tween completes.
  ///
  /// Resets [StepState.isAnimating] → widget returns [SizedBox.shrink].
  void _onCountUpComplete() {
    if (mounted) {
      ref.read(stepProvider.notifier).markAnimationComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to future transitions: isAnimating off→on (e.g. second hydration).
    ref.listen<StepState>(stepProvider, (previous, next) {
      final wasAnimating = previous?.isAnimating ?? false;
      if (next.isAnimating && next.loginDelta > 0 && !wasAnimating) {
        _startEntry();
      }
    });

    final stepState = ref.watch(stepProvider);

    // Guard: invisible on web (loginDelta == 0) and when not animating.
    if (!stepState.isAnimating || stepState.loginDelta <= 0) {
      return const SizedBox.shrink();
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: _RecapCard(
          loginDelta: stepState.loginDelta,
          lastSessionDate: stepState.lastSessionDate,
          onCountUpComplete: _onCountUpComplete,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

/// Frosted-glass card that displays the animated step count.
///
/// Extracted from [_StepRecapState] so the card layout is a simple
/// [StatelessWidget] and the animation logic stays in the parent state.
class _RecapCard extends StatelessWidget {
  final int loginDelta;
  final DateTime? lastSessionDate;
  final VoidCallback onCountUpComplete;

  const _RecapCard({
    required this.loginDelta,
    this.lastSessionDate,
    required this.onCountUpComplete,
  });

  /// Formats the subtitle based on [lastSessionDate].
  ///
  /// - Same day: "earned today"
  /// - Yesterday: "since yesterday"
  /// - Within current year: "since Mar 8"
  /// - Previous year: "since Mar 8, 2025"
  /// - Null (first launch): "earned while away"
  String _formatSubtitle(DateTime now) {
    final date = lastSessionDate;
    if (date == null) return 'earned while away';

    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(sessionDay).inDays;

    if (diff <= 0) return 'earned today';
    if (diff == 1) return 'since yesterday';

    final sameYear = date.year == now.year;
    final fmt = sameYear ? DateFormat.MMMd() : DateFormat.yMMMd();
    return 'since ${fmt.format(date)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final successColor = context.earthNova.successColor;
    final successContainerColor = context.earthNova.successContainerColor;

    return FrostedGlassContainer(
      isNotification: true,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xxl,
        vertical: Spacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Step icon ─────────────────────────────────────────────────────
          Container(
            width: ComponentSizes.notificationIcon + 4,
            height: ComponentSizes.notificationIcon + 4,
            decoration: BoxDecoration(
              color: successContainerColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '👣',
                style: const TextStyle(
                  fontSize: ComponentSizes.notificationIconSize,
                ),
              ),
            ),
          ),
          Spacing.gapSm,

          // ── "Step Recap" label ───────────────────────────────────────────
          Text(
            'Step Recap',
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),

          // ── Animated count ───────────────────────────────────────────────
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: loginDelta),
            duration: _kCountUpDuration,
            curve: Curves.easeOut,
            onEnd: onCountUpComplete,
            builder: (context, count, child) {
              return Text(
                '+$count',
                style: tt.displaySmall?.copyWith(
                  color: successColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.0,
                  height: 1.0,
                ),
              );
            },
          ),

          // ── "steps" unit ─────────────────────────────────────────────────
          Text(
            'steps',
            style: tt.bodyMedium?.copyWith(
              color: successColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          Spacing.gapXs,

          // ── Subtitle ─────────────────────────────────────────────────────
          Text(
            _formatSubtitle(DateTime.now()),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
