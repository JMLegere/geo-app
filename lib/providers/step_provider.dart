import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/data/location/mobile_pedometer_service.dart';
import 'package:earth_nova/providers/player_provider.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// Pedometer service interface
// ---------------------------------------------------------------------------

/// Abstract interface for OS step-count access.
///
/// Platform implementations: real pedometer (mobile), stub 0 (web).
abstract interface class PedometerService {
  /// Returns the cumulative OS step counter (monotonic until device reboot).
  Future<int> getCurrentStepCount();

  /// Disposes any active subscriptions.
  void dispose();
}

/// Default no-op pedometer — always returns 0 (web / test fallback).
class NoOpPedometer implements PedometerService {
  const NoOpPedometer();

  @override
  Future<int> getCurrentStepCount() async => 0;

  @override
  void dispose() {}
}

final pedometerServiceProvider = Provider<PedometerService>((ref) {
  // Use real OS pedometer on mobile; fall back to no-op on web and tests.
  if (!kIsWeb) {
    final svc = MobilePedometerService();
    ref.onDispose(svc.dispose);
    return svc;
  }
  return const NoOpPedometer();
});

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class StepState {
  /// Steps accumulated since last login (recap animation amount).
  final int loginDelta;

  /// Whether the recap count-up animation is currently playing.
  final bool isAnimating;

  /// Whether the recap animation has already completed this session.
  final bool hasAnimated;

  /// When the player's profile was last persisted (previous session).
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
  }) =>
      StepState(
        loginDelta: loginDelta ?? this.loginDelta,
        isAnimating: isAnimating ?? this.isAnimating,
        hasAnimated: hasAnimated ?? this.hasAnimated,
        lastSessionDate: lastSessionDate ?? this.lastSessionDate,
      );
}

// ---------------------------------------------------------------------------
// Provider + Notifier
// ---------------------------------------------------------------------------

final stepProvider =
    NotifierProvider<StepNotifier, StepState>(StepNotifier.new);

class StepNotifier extends Notifier<StepState> {
  @override
  StepState build() {
    ref.onDispose(() {
      ref.read(pedometerServiceProvider).dispose();
    });
    return const StepState();
  }

  /// Compute login delta and credit steps to playerProvider.
  ///
  /// [lastKnownStepCount] — last persisted OS step count.
  /// [totalSteps] — current accumulated total.
  /// [lastSessionDate] — for recap subtitle.
  Future<int> hydrate({
    required int lastKnownStepCount,
    required int totalSteps,
    DateTime? lastSessionDate,
  }) async {
    final pedometer = ref.read(pedometerServiceProvider);
    final currentOsSteps = await pedometer.getCurrentStepCount();

    final pedometerDelta = lastKnownStepCount > 0
        ? (currentOsSteps - lastKnownStepCount).clamp(0, currentOsSteps)
        : 0;

    final daysSince = lastSessionDate != null
        ? DateTime.now().difference(lastSessionDate).inDays.clamp(1, 30)
        : 1;
    final minimumGrant = kMinDailyStepGrant * daysSince;
    final delta = max(pedometerDelta, minimumGrant);

    if (delta > 0) {
      ref.read(playerProvider.notifier).addSteps(delta);
    }

    state = state.copyWith(
      loginDelta: delta,
      isAnimating: delta > 0,
      lastSessionDate: lastSessionDate,
    );

    debugPrint('[StepNotifier] hydrated: os=$currentOsSteps '
        'lastKnown=$lastKnownStepCount delta=$delta');

    return delta;
  }

  /// Called by the UI when the recap animation finishes.
  void markAnimationComplete() =>
      state = state.copyWith(isAnimating: false, hasAnimated: true);
}
