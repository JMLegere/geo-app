import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fog_of_world/core/config/supabase_bootstrap.dart';
import 'package:fog_of_world/core/state/collection_provider.dart';
import 'package:fog_of_world/core/state/supabase_bootstrap_provider.dart';
import 'package:fog_of_world/features/auth/models/auth_state.dart';
import 'package:fog_of_world/features/auth/models/user_profile.dart';
import 'package:fog_of_world/features/auth/providers/auth_provider.dart';
import 'package:fog_of_world/features/auth/providers/upgrade_prompt_provider.dart';

// ---------------------------------------------------------------------------
// Hand-written mocks (no mockito / mocktail)
// ---------------------------------------------------------------------------

/// Mutable mock collection notifier. [setCount] updates state so tests can
/// verify reactive rebuilds of [upgradePromptProvider].
///
/// Extends the concrete `CollectionNotifier` class so it satisfies the type
/// constraint of `collectionProvider.overrideWith`.
class _MockCollectionNotifier extends CollectionNotifier {
  final int _initialCount;

  _MockCollectionNotifier(this._initialCount);

  @override
  CollectionState build() => CollectionState(
        collectedSpeciesIds:
            List.generate(_initialCount, (i) => 'species_$i'),
      );

  void setCount(int count) {
    state = CollectionState(
      collectedSpeciesIds: List.generate(count, (i) => 'species_$i'),
    );
  }
}

/// Auth notifier mock that returns a fixed [AuthState] without any async work.
///
/// Extends the concrete `AuthNotifier` class so it satisfies the type
/// constraint of `authProvider.overrideWith`. Overrides `build` to skip
/// async initialization — tests only need a stable auth state.
class _MockAuthNotifier extends AuthNotifier {
  final bool _isAnonymous;

  _MockAuthNotifier({bool isAnonymous = true}) : _isAnonymous = isAnonymous;

  @override
  AuthState build() {
    // Override skips _initializeAuth() — tests don't need async auth ops.
    final user = UserProfile(
      id: 'mock-user',
      email: 'mock@example.com',
      createdAt: DateTime(2024),
      isAnonymous: _isAnonymous,
    );
    return AuthState.authenticated(user);
  }
}

/// [SupabaseBootstrap] subclass that exposes a fixed [initialized] value.
class _FakeBootstrap extends SupabaseBootstrap {
  final bool _initialized;

  _FakeBootstrap({required bool initialized}) : _initialized = initialized;

  @override
  bool get initialized => _initialized;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired with mock implementations.
///
/// [collectionCount] — how many species are in the collection initially.
/// [isAnonymous] — whether the auth user is anonymous.
/// [supabaseInitialized] — whether Supabase SDK initialized.
ProviderContainer _makeContainer({
  required int collectionCount,
  required bool isAnonymous,
  required bool supabaseInitialized,
}) {
  final container = ProviderContainer(
    overrides: [
      collectionProvider.overrideWith(
        () => _MockCollectionNotifier(collectionCount),
      ),
      authProvider.overrideWith(
        () => _MockAuthNotifier(isAnonymous: isAnonymous),
      ),
      supabaseBootstrapProvider.overrideWithValue(
        _FakeBootstrap(initialized: supabaseInitialized),
      ),
    ],
  );
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UpgradePromptState computed getters', () {
    test('shouldShow is false when below threshold', () {
      const state = UpgradePromptState(
        totalCollected: 4,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      expect(state.shouldShow, isFalse);
    });

    test('shouldShow is true at threshold when all conditions met', () {
      const state = UpgradePromptState(
        totalCollected: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      expect(state.shouldShow, isTrue);
    });

    test('shouldShow is false when hasBeenShown is true', () {
      const state = UpgradePromptState(
        totalCollected: 5,
        isAnonymous: true,
        supabaseInitialized: true,
        hasBeenShown: true,
      );
      expect(state.shouldShow, isFalse);
    });

    test('showBanner is true at threshold even when hasBeenShown', () {
      const state = UpgradePromptState(
        totalCollected: 5,
        isAnonymous: true,
        supabaseInitialized: true,
        hasBeenShown: true,
      );
      expect(state.showBanner, isTrue);
    });

    test('showBanner is false when user is not anonymous', () {
      const state = UpgradePromptState(
        totalCollected: 10,
        isAnonymous: false,
        supabaseInitialized: true,
      );
      expect(state.showBanner, isFalse);
    });

    test('showBanner is false when supabase is not initialized', () {
      const state = UpgradePromptState(
        totalCollected: 10,
        isAnonymous: true,
        supabaseInitialized: false,
      );
      expect(state.showBanner, isFalse);
    });
  });

  group('UpgradePromptNotifier', () {
    // ── Initial state ──────────────────────────────────────────────────────

    test('shouldShow is false when totalCollected < threshold (4 species)', () {
      final container = _makeContainer(
        collectionCount: 4,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
      expect(state.totalCollected, 4);
    });

    test('shouldShow fires at exactly threshold (5 species)', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isTrue);
      expect(state.showBanner, isTrue);
    });

    test('shouldShow fires above threshold (10 species)', () {
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).shouldShow, isTrue);
    });

    // ── Condition gates ────────────────────────────────────────────────────

    test('shouldShow is false when user is not anonymous', () {
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: false,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('shouldShow is false when Supabase is not initialized', () {
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: true,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('shouldShow is false when both conditions unmet', () {
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: false,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
    });

    // ── Boundary test ──────────────────────────────────────────────────────

    test('4 species = no prompt, 5 species = prompt (boundary)', () {
      final container4 = _makeContainer(
        collectionCount: 4,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container4.dispose);

      final container5 = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container5.dispose);

      expect(container4.read(upgradePromptProvider).shouldShow, isFalse);
      expect(container5.read(upgradePromptProvider).shouldShow, isTrue);
    });

    // ── markShown ──────────────────────────────────────────────────────────

    test('markShown() sets shouldShow to false while showBanner stays true',
        () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Verify prompt is initially eligible.
      expect(container.read(upgradePromptProvider).shouldShow, isTrue);

      // Mark as shown.
      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isTrue); // banner persists
      expect(state.hasBeenShown, isTrue);
    });

    test('markShown() is idempotent — calling twice has same result', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      container.read(upgradePromptProvider.notifier).markShown();
      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isTrue);
    });

    // ── Reactive rebuild preserves hasBeenShown ────────────────────────────

    test(
        'hasBeenShown is preserved across reactive rebuilds from collection changes',
        () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Show the prompt.
      container.read(upgradePromptProvider.notifier).markShown();
      expect(container.read(upgradePromptProvider).hasBeenShown, isTrue);

      // Simulate more species being collected — triggers reactive rebuild.
      (container.read(collectionProvider.notifier) as _MockCollectionNotifier)
          .setCount(8);

      // After rebuild, hasBeenShown must still be true.
      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 8);
      expect(state.hasBeenShown, isTrue);
      expect(state.shouldShow, isFalse); // sheet should NOT re-appear
      expect(state.showBanner, isTrue);
    });

    // ── showBanner after account upgrade ──────────────────────────────────

    test('showBanner becomes false when user upgrades (isAnonymous → false)',
        () {
      // Use separate containers because auth state is fixed at construction.
      // This tests the computed value on a non-anonymous state.
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: false, // user has upgraded
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.showBanner, isFalse);
      expect(state.shouldShow, isFalse);
    });

    // ── Initial state reflects providers ──────────────────────────────────

    test('initial state correctly reflects provider values', () {
      final container = _makeContainer(
        collectionCount: 3,
        isAnonymous: true,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 3);
      expect(state.isAnonymous, isTrue);
      expect(state.supabaseInitialized, isFalse);
      expect(state.hasBeenShown, isFalse);
    });
  });
}
