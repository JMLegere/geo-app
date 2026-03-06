import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/core/state/supabase_bootstrap_provider.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/shared/constants.dart';

// ---------------------------------------------------------------------------
// UpgradePromptState
// ---------------------------------------------------------------------------

/// Immutable state for the upgrade prompt feature.
///
/// Tracks whether an anonymous user has crossed the collection threshold and
/// should be prompted to create an account.
///
/// Note: [shouldShow] is false on first build because [collectionProvider]
/// initializes with an empty [CollectionState] (`totalCollected == 0`). The
/// prompt becomes eligible only after the discovery flow hydrates the
/// collection by adding species via [CollectionNotifier.addSpecies].
class UpgradePromptState {
  const UpgradePromptState({
    required this.totalCollected,
    required this.isAnonymous,
    required this.supabaseInitialized,
    this.hasBeenShown = false,
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

  /// Whether to show the one-time upgrade bottom sheet.
  ///
  /// True only when all conditions are met AND the sheet has not yet been shown
  /// this session. Becomes false after [UpgradePromptNotifier.markShown] is
  /// called.
  bool get shouldShow =>
      totalCollected >= kUpgradePromptThreshold &&
      isAnonymous &&
      supabaseInitialized &&
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
  }) {
    return UpgradePromptState(
      totalCollected: totalCollected ?? this.totalCollected,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      supabaseInitialized: supabaseInitialized ?? this.supabaseInitialized,
      hasBeenShown: hasBeenShown ?? this.hasBeenShown,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UpgradePromptState &&
        other.totalCollected == totalCollected &&
        other.isAnonymous == isAnonymous &&
        other.supabaseInitialized == supabaseInitialized &&
        other.hasBeenShown == hasBeenShown;
  }

  @override
  int get hashCode =>
      Object.hash(totalCollected, isAnonymous, supabaseInitialized, hasBeenShown);

  @override
  String toString() => 'UpgradePromptState('
      'totalCollected: $totalCollected, '
      'isAnonymous: $isAnonymous, '
      'supabaseInitialized: $supabaseInitialized, '
      'hasBeenShown: $hasBeenShown, '
      'shouldShow: $shouldShow, '
      'showBanner: $showBanner)';
}

// ---------------------------------------------------------------------------
// UpgradePromptNotifier
// ---------------------------------------------------------------------------

/// Reactive notifier that evaluates whether to prompt an anonymous user to
/// upgrade their account after collecting [kUpgradePromptThreshold] species.
///
/// Watches [collectionProvider] and [authProvider] so state recomputes
/// automatically whenever collection or auth changes. Reads
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
    final totalCollected = ref.watch(collectionProvider).totalCollected;
    final isAnonymous = ref.watch(authProvider).isAnonymous;
    // supabaseBootstrapProvider is a plain Provider (not Notifier) — its value
    // is stable after app startup, so read() is sufficient here.
    final supabaseInitialized =
        ref.read(supabaseBootstrapProvider).initialized;

    return UpgradePromptState(
      totalCollected: totalCollected,
      isAnonymous: isAnonymous,
      supabaseInitialized: supabaseInitialized,
      hasBeenShown: _hasBeenShown,
    );
  }

  /// Session-level flag. Stored as an instance field so that reactive rebuilds
  /// triggered by [collectionProvider] or [authProvider] do not reset it —
  /// [build] reads [_hasBeenShown] directly rather than inspecting [state].
  bool _hasBeenShown = false;

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
