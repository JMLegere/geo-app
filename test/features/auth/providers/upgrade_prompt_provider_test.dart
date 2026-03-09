import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
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
            displayName: 'Test Species',
            category: ItemCategory.fauna,
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
          displayName: 'Test Species',
          category: ItemCategory.fauna,
          acquiredAt: DateTime(2024),
          acquiredInCellId: 'cell_1',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired with mock implementations.
///
/// [collectionCount] — how many items are in the inventory initially.
/// [supabaseInitialized] — whether Supabase SDK initialized.
ProviderContainer _makeContainer({
  required int collectionCount,
  required bool supabaseInitialized,
}) {
  final container = ProviderContainer(
    overrides: [
      inventoryProvider.overrideWith(
        () => _MockInventoryNotifier(collectionCount),
      ),
      supabaseBootstrapProvider.overrideWithValue(supabaseInitialized),
    ],
  );
  return container;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('UpgradePromptState computed getters', () {
    test('shouldShow is always false', () {
      const state = UpgradePromptState(
        totalCollected: 10,
        supabaseInitialized: true,
        sessionTimeElapsed: true,
      );
      expect(state.shouldShow, isFalse);
    });

    test('showBanner is always false', () {
      const state = UpgradePromptState(
        totalCollected: 10,
        supabaseInitialized: true,
        sessionTimeElapsed: true,
      );
      expect(state.showBanner, isFalse);
    });

    test('shouldShow is false even when all conditions would be met', () {
      const state = UpgradePromptState(
        totalCollected: 5,
        supabaseInitialized: true,
        sessionTimeElapsed: true,
      );
      expect(state.shouldShow, isFalse);
    });

    test('showBanner is false even when supabase is initialized', () {
      const state = UpgradePromptState(
        totalCollected: 10,
        supabaseInitialized: true,
      );
      expect(state.showBanner, isFalse);
    });

    test('showBanner is false when supabase is not initialized', () {
      const state = UpgradePromptState(
        totalCollected: 10,
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
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
      expect(state.totalCollected, 4);
    });

    test('shouldShow is false even at threshold (always false)', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    // ── Condition gates ────────────────────────────────────────────────────

    test('shouldShow is false when Supabase is not initialized', () {
      final container = _makeContainer(
        collectionCount: 10,
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
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
    });

    // ── markShown ──────────────────────────────────────────────────────────

    test('markShown() sets hasBeenShown to true', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Mark as shown.
      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.hasBeenShown, isTrue);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('markShown() is idempotent — calling twice has same result', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      container.read(upgradePromptProvider.notifier).markShown();
      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
      expect(state.hasBeenShown, isTrue);
    });

    // ── Reactive rebuild preserves hasBeenShown ────────────────────────────

    test(
        'hasBeenShown is preserved across reactive rebuilds from inventory changes',
        () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      // Mark as shown.
      container.read(upgradePromptProvider.notifier).markShown();
      expect(container.read(upgradePromptProvider).hasBeenShown, isTrue);

      // Simulate more items being collected — triggers reactive rebuild.
      (container.read(inventoryProvider.notifier) as _MockInventoryNotifier)
          .setCount(8);

      // After rebuild, hasBeenShown must still be true.
      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 8);
      expect(state.hasBeenShown, isTrue);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    // ── Initial state reflects providers ──────────────────────────────────

    test('initial state correctly reflects provider values', () {
      final container = _makeContainer(
        collectionCount: 3,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 3);
      expect(state.supabaseInitialized, isFalse);
      expect(state.hasBeenShown, isFalse);
    });

    test('totalCollected reflects inventory count', () {
      final container = _makeContainer(
        collectionCount: 7,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 7);
    });

    test('supabaseInitialized reflects provider value', () {
      final container = _makeContainer(
        collectionCount: 0,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.supabaseInitialized, isTrue);
    });
  });
}
