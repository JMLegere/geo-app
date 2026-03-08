import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/shared/constants.dart';

// ---------------------------------------------------------------------------
// UpgradePromptState
// ---------------------------------------------------------------------------

/// Immutable state for the upgrade prompt feature.
///
/// Tracks whether an anonymous user has crossed the collection threshold and
/// should be prompted to create an account.
///
/// Note: [shouldShow] is false on first build because [inventoryProvider]
/// initializes with an empty [InventoryState] (`totalItems == 0`). The
/// prompt becomes eligible only after the discovery flow hydrates the
/// inventory by adding items via [InventoryNotifier.addItem].
class UpgradePromptState {
  const UpgradePromptState({
    required this.totalCollected,
    required this.isAnonymous,
    required this.supabaseInitialized,
    this.hasBeenShown = false,
    this.sessionTimeElapsed = false,
  });

  /// Total species collected by the player this session.
  final int totalCollected;

  /// Whether the current auth user is anonymous (not upgraded).
  final bool isAnonymous;

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
  /// True only when all conditions are met AND the sheet has not yet been shown
  /// this session. Requires both [kUpgradePromptThreshold] species collected
  /// AND [kUpgradePromptDelaySeconds] elapsed since app open to prevent
  /// interrupting early exploration.
  bool get shouldShow =>
      totalCollected >= kUpgradePromptThreshold &&
      isAnonymous &&
      supabaseInitialized &&
      sessionTimeElapsed &&
      !hasBeenShown;

  /// Whether to show the persistent upgrade banner.
  ///
  /// True once the threshold is crossed (anonymous + Supabase configured),
  /// regardless of whether the bottom sheet has been shown. Remains true
  /// until the user upgrades their account.
  bool get showBanner =>
      totalCollected >= kUpgradePromptThreshold &&
      isAnonymous &&
      supabaseInitialized;

  UpgradePromptState copyWith({
    int? totalCollected,
    bool? isAnonymous,
    bool? supabaseInitialized,
    bool? hasBeenShown,
    bool? sessionTimeElapsed,
  }) {
    return UpgradePromptState(
      totalCollected: totalCollected ?? this.totalCollected,
      isAnonymous: isAnonymous ?? this.isAnonymous,
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
        other.isAnonymous == isAnonymous &&
        other.supabaseInitialized == supabaseInitialized &&
        other.hasBeenShown == hasBeenShown &&
        other.sessionTimeElapsed == sessionTimeElapsed;
  }

  @override
  int get hashCode => Object.hash(totalCollected, isAnonymous,
      supabaseInitialized, hasBeenShown, sessionTimeElapsed);

  @override
  String toString() => 'UpgradePromptState('
      'totalCollected: $totalCollected, '
      'isAnonymous: $isAnonymous, '
      'supabaseInitialized: $supabaseInitialized, '
      'hasBeenShown: $hasBeenShown, '
      'sessionTimeElapsed: $sessionTimeElapsed, '
      'shouldShow: $shouldShow, '
      'showBanner: $showBanner)';
}

// ---------------------------------------------------------------------------
// UpgradePromptNotifier
// ---------------------------------------------------------------------------

/// Reactive notifier that evaluates whether to prompt an anonymous user to
/// upgrade their account after collecting [kUpgradePromptThreshold] species.
///
/// Watches [inventoryProvider] and [authProvider] so state recomputes
/// automatically whenever inventory or auth changes. Reads
/// [supabaseBootstrapProvider] once — the initialized flag is stable after
/// app startup and does not change at runtime.
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
    final totalCollected = ref.watch(inventoryProvider).totalItems;
    final isAnonymous = ref.watch(authProvider).isAnonymous;
    // supabaseBootstrapProvider is a plain Provider (not Notifier) — its value
    // is stable after app startup, so read() is sufficient here.
    final supabaseInitialized = ref.read(supabaseBootstrapProvider).initialized;

    // Start session timer on first build. The timer fires once after
    // kUpgradePromptDelaySeconds and sets the flag so subsequent reactive
    // rebuilds (from inventory/auth changes) see it as true.
    _startSessionTimer();

    return UpgradePromptState(
      totalCollected: totalCollected,
      isAnonymous: isAnonymous,
      supabaseInitialized: supabaseInitialized,
      hasBeenShown: _hasBeenShown,
      sessionTimeElapsed: _sessionTimeElapsed,
    );
  }

  /// Session-level flag. Stored as an instance field so that reactive rebuilds
  /// triggered by [inventoryProvider] or [authProvider] do not reset it —
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
