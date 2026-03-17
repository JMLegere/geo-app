import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/features/items/providers/items_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// UpgradePromptState
// ---------------------------------------------------------------------------

/// Immutable state for the upgrade prompt feature.
///
/// Tracks whether the player has crossed the collection threshold and
/// should be prompted to save progress. Login is now required, so this
/// prompt is always disabled — [shouldShow] and [showBanner] always return
/// false. Retained for structural compatibility pending full removal in
/// Task 18.
///
/// Note: [shouldShow] is false on first build because [itemsProvider]
/// initializes with an empty [ItemsState] (`totalItems == 0`). The
/// prompt becomes eligible only after the discovery flow hydrates the
/// inventory by adding items via [ItemsNotifier.addItem].
class UpgradePromptState {
  const UpgradePromptState({
    required this.totalCollected,
    required this.supabaseInitialized,
    this.hasBeenShown = false,
    this.sessionTimeElapsed = false,
  });

  /// Total species collected by the player this session.
  final int totalCollected;

  /// Whether the Supabase SDK initialized successfully.
  final bool supabaseInitialized;

  /// Whether the upgrade bottom sheet has been shown this session.
  ///
  /// Session-level only — deliberately NOT persisted to SQLite.
  /// Resets to false on app restart so the prompt re-appears if the user is
  /// still anonymous after restarting.
  final bool hasBeenShown;

  /// Whether the minimum session time has elapsed (cooldown after app open).
  ///
  /// Becomes true after [kUpgradePromptDelaySeconds] since the notifier was
  /// first built (i.e. app open). Prevents interrupting early exploration.
  final bool sessionTimeElapsed;

  /// Whether to show the one-time upgrade bottom sheet.
  ///
  /// Always false — login is required so no upgrade prompt is needed.
  bool get shouldShow => false;

  /// Whether to show the persistent upgrade banner.
  ///
  /// Always false — login is required so no upgrade banner is needed.
  bool get showBanner => false;

  UpgradePromptState copyWith({
    int? totalCollected,
    bool? supabaseInitialized,
    bool? hasBeenShown,
    bool? sessionTimeElapsed,
  }) {
    return UpgradePromptState(
      totalCollected: totalCollected ?? this.totalCollected,
      supabaseInitialized: supabaseInitialized ?? this.supabaseInitialized,
      hasBeenShown: hasBeenShown ?? this.hasBeenShown,
      sessionTimeElapsed: sessionTimeElapsed ?? this.sessionTimeElapsed,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpgradePromptState &&
        other.totalCollected == totalCollected &&
        other.supabaseInitialized == supabaseInitialized &&
        other.hasBeenShown == hasBeenShown &&
        other.sessionTimeElapsed == sessionTimeElapsed;
  }

  @override
  int get hashCode => Object.hash(
      totalCollected, supabaseInitialized, hasBeenShown, sessionTimeElapsed);

  @override
  String toString() => 'UpgradePromptState('
      'totalCollected: $totalCollected, '
      'supabaseInitialized: $supabaseInitialized, '
      'hasBeenShown: $hasBeenShown, '
      'sessionTimeElapsed: $sessionTimeElapsed, '
      'shouldShow: $shouldShow, '
      'showBanner: $showBanner)';
}

// ---------------------------------------------------------------------------
// UpgradePromptNotifier
// ---------------------------------------------------------------------------

/// Reactive notifier that evaluates whether to prompt a user to upgrade.
///
/// Login is now required, so [shouldShow] and [showBanner] always return
/// false. Retained for structural compatibility pending full removal in
/// Task 18.
///
/// Watches [itemsProvider] so state recomputes automatically whenever
/// inventory changes. Reads [supabaseBootstrapProvider] once — the
/// initialized flag is stable after app startup and does not change at runtime.
///
/// Usage:
/// ```dart
/// // In a widget build:
/// final promptState = ref.watch(upgradePromptProvider);
/// if (promptState.shouldShow) {
///   // Show bottom sheet, then:
///   ref.read(upgradePromptProvider.notifier).markShown();
/// }
/// ```
class UpgradePromptNotifier extends Notifier<UpgradePromptState> {
  @override
  UpgradePromptState build() {
    final totalCollected = ref.watch(itemsProvider).totalItems;
    // supabaseBootstrapProvider returns bool directly — stable after app startup.
    final supabaseInitialized = ref.read(supabaseBootstrapProvider);

    // Start session timer on first build. The timer fires once after
    // kUpgradePromptDelaySeconds and sets the flag so subsequent reactive
    // rebuilds (from inventory changes) see it as true.
    _startSessionTimer();

    return UpgradePromptState(
      totalCollected: totalCollected,
      supabaseInitialized: supabaseInitialized,
      hasBeenShown: _hasBeenShown,
      sessionTimeElapsed: _sessionTimeElapsed,
    );
  }

  /// Session-level flag. Stored as an instance field so that reactive rebuilds
  /// triggered by [itemsProvider] do not reset it —
  /// [build] reads [_hasBeenShown] directly rather than inspecting [state].
  bool _hasBeenShown = false;

  /// Whether [kUpgradePromptDelaySeconds] have elapsed since first build.
  bool _sessionTimeElapsed = false;

  /// Guard to ensure only one timer is started.
  Timer? _sessionTimer;

  /// Starts a one-shot timer that enables the prompt after the delay.
  void _startSessionTimer() {
    if (_sessionTimer != null) return;
    _sessionTimer = Timer(
      const Duration(seconds: kUpgradePromptDelaySeconds),
      () {
        _sessionTimeElapsed = true;
        if (ref.mounted) {
          state = state.copyWith(sessionTimeElapsed: true);
        }
      },
    );
    ref.onDispose(() {
      _sessionTimer?.cancel();
      _sessionTimer = null;
    });
  }

  /// Marks the upgrade bottom sheet as shown this session.
  ///
  /// After calling this, [UpgradePromptState.shouldShow] becomes false so the
  /// sheet is not re-shown. [UpgradePromptState.showBanner] remains true to
  /// keep a persistent banner visible until the user upgrades.
  void markShown() {
    _hasBeenShown = true;
    state = state.copyWith(hasBeenShown: true);
  }
}

/// Global provider for [UpgradePromptNotifier].
final upgradePromptProvider =
    NotifierProvider<UpgradePromptNotifier, UpgradePromptState>(
  UpgradePromptNotifier.new,
);
