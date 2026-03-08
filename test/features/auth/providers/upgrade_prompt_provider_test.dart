import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/config/supabase_bootstrap.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';

// ---------------------------------------------------------------------------
// Hand-written mocks (no mockito / mocktail)
// ---------------------------------------------------------------------------

/// Mutable mock inventory notifier. [setCount] updates state so tests can
/// verify reactive rebuilds of [upgradePromptProvider].
///
/// Extends the concrete `InventoryNotifier` class so it satisfies the type
/// constraint of `inventoryProvider.overrideWith`.
class _MockInventoryNotifier extends InventoryNotifier {
  final int _initialCount;

  _MockInventoryNotifier(this._initialCount);

  @override
  InventoryState build() => InventoryState(
        items: List.generate(
          _initialCount,
          (i) => ItemInstance(
            id: 'mock_item_$i',
            definitionId: 'species_$i',
            acquiredAt: DateTime(2024),
            acquiredInCellId: 'cell_1',
          ),
        ),
      );

  void setCount(int count) {
    state = InventoryState(
      items: List.generate(
        count,
        (i) => ItemInstance(
          id: 'mock_item_$i',
          definitionId: 'species_$i',
          acquiredAt: DateTime(2024),
          acquiredInCellId: 'cell_1',
        ),
      ),
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
/// [collectionCount] — how many items are in the inventory initially.
/// [isAnonymous] — whether the auth user is anonymous.
/// [supabaseInitialized] — whether Supabase SDK initialized.
ProviderContainer _makeContainer({
  required int collectionCount,
  required bool isAnonymous,
  required bool supabaseInitialized,
}) {
  final container = ProviderContainer(
    overrides: [
      inventoryProvider.overrideWith(
        () => _MockInventoryNotifier(collectionCount),
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
        sessionTimeElapsed: true,
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

    test('shouldShow is false before session delay elapses', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Timer hasn't fired yet — sessionTimeElapsed is false.
      final state = container.read(upgradePromptProvider);
      expect(state.sessionTimeElapsed, isFalse);
      expect(state.shouldShow, isFalse);
      // Banner doesn't depend on sessionTimeElapsed.
      expect(state.showBanner, isTrue);
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

    test('4 species = no prompt, 5 species = prompt (boundary via state)', () {
      // Test the boundary via pure state (sessionTimeElapsed: true simulates
      // post-delay). Notifier-level tests verify timer sets this flag.
      const state4 = UpgradePromptState(
        totalCollected: 4,
        isAnonymous: true,
        supabaseInitialized: true,
        sessionTimeElapsed: true,
      );
      const state5 = UpgradePromptState(
        totalCollected: 5,
        isAnonymous: true,
        supabaseInitialized: true,
        sessionTimeElapsed: true,
      );

      expect(state4.shouldShow, isFalse);
      expect(state5.shouldShow, isTrue);
    });

    // ── markShown ──────────────────────────────────────────────────────────

    test('markShown() sets hasBeenShown to true while showBanner stays true',
        () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Mark as shown.
      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.hasBeenShown, isTrue);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isTrue); // banner persists
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
        'hasBeenShown is preserved across reactive rebuilds from inventory changes',
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

      // Simulate more items being collected — triggers reactive rebuild.
      (container.read(inventoryProvider.notifier) as _MockInventoryNotifier)
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
