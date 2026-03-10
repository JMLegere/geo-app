import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/player_provider.dart';
import 'package:earth_nova/features/steps/services/step_service.dart';

// ---------------------------------------------------------------------------
// Service provider (overridable for testing)
// ---------------------------------------------------------------------------

/// Provides the [StepService] instance used by [StepNotifier].
///
/// Override in tests to inject a mock [StepService]:
/// ```dart
/// container = ProviderContainer(overrides: [
///   stepServiceProvider.overrideWithValue(MockStepService()),
/// ]);
/// ```
final stepServiceProvider = Provider<StepService>((ref) => StepService());

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable step-counting state for the recap animation and live counter.
class StepState {
  /// Steps accumulated since last login (the recap amount).
  final int loginDelta;

  /// Whether the recap count-up animation is currently playing.
  final bool isAnimating;

  /// Whether the recap animation has already completed this session.
  final bool hasAnimated;

  /// When the player's profile was last persisted (i.e. their previous session).
  ///
  /// Used by [StepRecap] to display "since Mar 8" instead of the generic
  /// "earned while away". Null on first launch (no prior session).
  final DateTime? lastSessionDate;

  const StepState({
    this.loginDelta = 0,
    this.isAnimating = false,
    this.hasAnimated = false,
    this.lastSessionDate,
  });

  StepState copyWith({
    int? loginDelta,
    bool? isAnimating,
    bool? hasAnimated,
    DateTime? lastSessionDate,
  }) {
    return StepState(
      loginDelta: loginDelta ?? this.loginDelta,
      isAnimating: isAnimating ?? this.isAnimating,
      hasAnimated: hasAnimated ?? this.hasAnimated,
      lastSessionDate: lastSessionDate ?? this.lastSessionDate,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

/// Manages step counting: login delta calculation, recap animation state,
/// and live step stream forwarding to [PlayerNotifier].
///
/// Lifecycle:
/// 1. [hydrate] called by gameCoordinatorProvider during startup.
///    Reads OS step counter, computes delta vs persisted baseline,
///    adds delta to PlayerState.totalSteps.
/// 2. [startLiveStream] subscribes to the continuous pedometer stream
///    and adds incremental steps to PlayerState in real-time.
/// 3. [markAnimationComplete] called by UI when the recap animation
///    finishes playing.
class StepNotifier extends Notifier<StepState> {
  late final StepService _stepService;
  StreamSubscription<int>? _liveSub;
  int? _lastStreamValue;

  @override
  StepState build() {
    _stepService = ref.read(stepServiceProvider);

    ref.onDispose(() {
      _liveSub?.cancel();
      _stepService.dispose();
    });

    return const StepState();
  }

  /// Computes the login delta and updates player state.
  ///
  /// Called once during startup hydration with the persisted baseline.
  /// [lastSessionDate] is the profile's `updatedAt` timestamp — when the
  /// player's previous session last wrote to the database. Passed through to
  /// [StepState.lastSessionDate] for the recap subtitle.
  ///
  /// Returns the computed delta for logging.
  Future<int> hydrate({
    required int lastKnownStepCount,
    required int totalSteps,
    DateTime? lastSessionDate,
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
      lastSessionDate: lastSessionDate,
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

  /// Called by UI when the recap animation finishes.
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
