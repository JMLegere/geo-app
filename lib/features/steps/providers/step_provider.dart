import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/player_provider.dart';
import 'package:fog_of_world/features/steps/services/step_service.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable step-counting state for the cha-ching animation and live counter.
class StepState {
  /// Steps accumulated since last login (the "cha-ching" amount).
  final int loginDelta;

  /// Whether the cha-ching count-up animation is currently playing.
  final bool isAnimating;

  /// Whether the cha-ching animation has already completed this session.
  final bool hasAnimated;

  const StepState({
    this.loginDelta = 0,
    this.isAnimating = false,
    this.hasAnimated = false,
  });

  StepState copyWith({
    int? loginDelta,
    bool? isAnimating,
    bool? hasAnimated,
  }) {
    return StepState(
      loginDelta: loginDelta ?? this.loginDelta,
      isAnimating: isAnimating ?? this.isAnimating,
      hasAnimated: hasAnimated ?? this.hasAnimated,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages step counting: login delta calculation, cha-ching animation state,
/// and live step stream forwarding to [PlayerNotifier].
///
/// Lifecycle:
/// 1. [hydrate] called by gameCoordinatorProvider during startup.
///    Reads OS step counter, computes delta vs persisted baseline,
///    adds delta to PlayerState.totalSteps.
/// 2. [startLiveStream] subscribes to the continuous pedometer stream
///    and adds incremental steps to PlayerState in real-time.
/// 3. [markAnimationComplete] called by UI when the cha-ching animation
///    finishes playing.
class StepNotifier extends Notifier<StepState> {
  late final StepService _stepService;
  StreamSubscription<int>? _liveSub;
  int? _lastStreamValue;

  @override
  StepState build() {
    _stepService = StepService();

    ref.onDispose(() {
      _liveSub?.cancel();
      _stepService.dispose();
    });

    return const StepState();
  }

  /// Computes the login delta and updates player state.
  ///
  /// Called once during startup hydration with the persisted baseline.
  /// Returns the computed delta for logging.
  Future<int> hydrate({
    required int lastKnownStepCount,
    required int totalSteps,
  }) async {
    final currentOsSteps = await _stepService.getCurrentStepCount();

    // Compute delta. Clamp to ≥ 0 to handle device reboot (OS counter resets).
    final delta = lastKnownStepCount > 0
        ? (currentOsSteps - lastKnownStepCount).clamp(0, currentOsSteps)
        : 0;

    if (delta > 0) {
      ref.read(playerProvider.notifier).addSteps(delta);
    }

    // Store for live stream baseline.
    _lastStreamValue = currentOsSteps;

    state = state.copyWith(
      loginDelta: delta,
      isAnimating: delta > 0,
    );

    debugPrint('[StepNotifier] hydrated: os=$currentOsSteps, '
        'lastKnown=$lastKnownStepCount, delta=$delta, '
        'newTotal=${totalSteps + delta}');

    return delta;
  }

  /// Subscribes to the live pedometer stream for real-time step updates.
  ///
  /// Each emission adds the incremental delta to PlayerState.totalSteps.
  void startLiveStream() {
    _stepService.start();
    _liveSub = _stepService.stepCountStream.listen((int osSteps) {
      final prev = _lastStreamValue ?? osSteps;
      final increment = (osSteps - prev).clamp(0, osSteps);
      _lastStreamValue = osSteps;

      if (increment > 0) {
        ref.read(playerProvider.notifier).addSteps(increment);
      }
    });
  }

  /// Called by UI when the cha-ching animation finishes.
  void markAnimationComplete() {
    state = state.copyWith(
      isAnimating: false,
      hasAnimated: true,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final stepProvider =
    NotifierProvider<StepNotifier, StepState>(StepNotifier.new);
