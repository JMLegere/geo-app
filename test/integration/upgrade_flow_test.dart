/// Integration test: upgrade flow wired across SanctuaryScreen, PackScreen,
/// and SettingsScreen.
///
/// Tests the full end-to-end upgrade prompt lifecycle:
/// 1. UpgradePromptProvider state transitions (totalCollected, markShown, etc.)
/// 2. Supabase gate (prompt suppressed when SDK not initialized)
/// 3. SaveProgressBanner visibility in SanctuaryScreen and PackScreen
///    (always hidden — showBanner is hardcoded false)
///
/// All mocks are hand-written — no mockito / mocktail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/models/item_category.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/auth/widgets/save_progress_banner.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/pack/screens/pack_screen.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';

// ---------------------------------------------------------------------------
// Hand-written mocks
// ---------------------------------------------------------------------------

/// Mock inventory notifier with mutable count for reactive testing.
class _MockInventoryNotifier extends InventoryNotifier {
  _MockInventoryNotifier(this._initialCount);

  final int _initialCount;

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

/// Stub notifier that watches real providers but skips the session timer.
///
/// The real [UpgradePromptNotifier] starts a 120-second [Timer] on build,
/// which causes "Pending timers" failures in widget tests. This stub
/// preserves reactive integration (watches inventory/supabase) while
/// bypassing the timer by setting [sessionTimeElapsed] = true immediately.
class _IntegrationUpgradePromptNotifier extends UpgradePromptNotifier {
  bool _hasBeenShown = false;

  @override
  UpgradePromptState build() {
    final totalCollected = ref.watch(inventoryProvider).totalItems;
    // supabaseBootstrapProvider returns bool directly.
    final supabaseInitialized = ref.read(supabaseBootstrapProvider);

    return UpgradePromptState(
      totalCollected: totalCollected,
      supabaseInitialized: supabaseInitialized,
      hasBeenShown: _hasBeenShown,
      sessionTimeElapsed: true, // Timer bypassed in tests
    );
  }

  @override
  void markShown() {
    _hasBeenShown = true;
    state = state.copyWith(hasBeenShown: true);
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [ProviderContainer] wired with mock implementations.
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
      upgradePromptProvider.overrideWith(
        () => _IntegrationUpgradePromptNotifier(),
      ),
    ],
  );
  return container;
}

/// Minimal species fixture for widget tests.
final _testSpecies = [
  FaunaDefinition(
    id: 'fauna_vulpes_vulpes',
    displayName: 'Red Fox',
    scientificName: 'Vulpes vulpes',
    taxonomicClass: 'Mammalia',
    continents: [Continent.europe],
    habitats: [Habitat.forest],
    rarity: IucnStatus.leastConcern,
  ),
];

/// Pumps [SanctuaryScreen] with mocked providers.
Future<ProviderContainer> _pumpSanctuaryScreen(
  WidgetTester tester, {
  required int collectionCount,
  required bool supabaseInitialized,
}) async {
  final container = ProviderContainer(
    overrides: [
      inventoryProvider.overrideWith(
        () => _MockInventoryNotifier(collectionCount),
      ),
      supabaseBootstrapProvider.overrideWithValue(supabaseInitialized),
      speciesServiceProvider.overrideWith(
        (_) => SpeciesService(_testSpecies),
      ),
      upgradePromptProvider.overrideWith(
        () => _IntegrationUpgradePromptNotifier(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SanctuaryScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// Pumps [PackScreen] with mocked providers.
Future<ProviderContainer> _pumpPackScreen(
  WidgetTester tester, {
  required int collectionCount,
  required bool supabaseInitialized,
}) async {
  final container = ProviderContainer(
    overrides: [
      inventoryProvider.overrideWith(
        () => _MockInventoryNotifier(collectionCount),
      ),
      supabaseBootstrapProvider.overrideWithValue(supabaseInitialized),
      speciesServiceProvider.overrideWith(
        (_) => SpeciesService(_testSpecies),
      ),
      upgradePromptProvider.overrideWith(
        () => _IntegrationUpgradePromptNotifier(),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: PackScreen()),
    ),
  );
  await tester.pump();
  return container;
}

/// Top-level helper for standalone SaveProgressBanner widget tests.
Widget _wrapBanner({required bool showBanner}) {
  return ProviderScope(
    overrides: [
      upgradePromptProvider.overrideWith(
        () => _StubUpgradePromptNotifier(showBanner: showBanner),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: SaveProgressBanner(onUpgradeTap: _noOp),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Provider-level: full upgrade flow ─────────────────────────────────────

  group('UpgradePromptProvider full flow', () {
    test('collection 0→4: shouldShow and showBanner both false', () {
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

    test('collection reaches 5: shouldShow and showBanner both false (always)',
        () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('markShown() sets hasBeenShown=true', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
      expect(state.hasBeenShown, isTrue);
    });

    test('hasBeenShown preserved across reactive rebuilds', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      container.read(upgradePromptProvider.notifier).markShown();
      expect(container.read(upgradePromptProvider).hasBeenShown, isTrue);

      // Simulate more species collected — triggers reactive rebuild.
      (container.read(inventoryProvider.notifier) as _MockInventoryNotifier)
          .setCount(10);

      final state = container.read(upgradePromptProvider);
      expect(state.totalCollected, 10);
      expect(state.hasBeenShown, isTrue);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('totalCollected reflects inventory', () {
      final container = _makeContainer(
        collectionCount: 7,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).totalCollected, 7);
    });
  });

  // ── Supabase gate ─────────────────────────────────────────────────────────

  group('Supabase gate', () {
    test(
        'shouldShow is false when supabaseInitialized=false regardless of count',
        () {
      final container = _makeContainer(
        collectionCount: 10,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
    });

    test('showBanner is false when supabaseInitialized=false', () {
      final container = _makeContainer(
        collectionCount: 20,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).showBanner, isFalse);
    });

    test('supabaseInitialized=true is reflected in state', () {
      final container = _makeContainer(
        collectionCount: 5,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).supabaseInitialized, isTrue);
    });
  });

  // ── SanctuaryScreen widget tests ─────────────────────────────────────────

  group('SanctuaryScreen includes SaveProgressBanner', () {
    // showBanner is always false — banner text never appears.

    testWidgets('banner is hidden when collection is below threshold',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 2,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when supabase not initialized',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 10,
        supabaseInitialized: false,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden even when collection threshold met',
        (tester) async {
      // showBanner is always false — login is required, no upgrade prompt.
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 5,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });
  });

  // ── PackScreen widget tests ────────────────────────────────────────────────

  group('PackScreen includes SaveProgressBanner', () {
    testWidgets('banner widget is present in tree (may be hidden)',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 0,
        supabaseInitialized: true,
      );

      expect(find.byType(SaveProgressBanner), findsOneWidget);
    });

    testWidgets('banner is hidden when collection is below threshold',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 3,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when supabase not initialized',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 10,
        supabaseInitialized: false,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden even when collection threshold met',
        (tester) async {
      // showBanner is always false — login is required, no upgrade prompt.
      await _pumpPackScreen(
        tester,
        collectionCount: 5,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });
  });

  // ── SaveProgressBanner standalone widget tests ────────────────────────────

  group('SaveProgressBanner widget', () {
    testWidgets('renders nothing when showBanner=false', (tester) async {
      await tester.pumpWidget(_wrapBanner(showBanner: false));
      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('renders nothing when showBanner=true (always false in prod)',
        (tester) async {
      // _StubUpgradePromptNotifier sets fields but showBanner getter is
      // always false in production UpgradePromptState.
      await tester.pumpWidget(_wrapBanner(showBanner: true));
      expect(find.text('Save your progress'), findsNothing);
    });
  });
}

// ---------------------------------------------------------------------------
// Supporting stubs for SaveProgressBanner standalone tests
// ---------------------------------------------------------------------------

void _noOp() {}

class _StubUpgradePromptNotifier extends UpgradePromptNotifier {
  _StubUpgradePromptNotifier({required bool showBanner})
      : _showBanner = showBanner;

  final bool _showBanner;

  @override
  UpgradePromptState build() => UpgradePromptState(
        totalCollected: _showBanner ? 10 : 0,
        supabaseInitialized: _showBanner,
        sessionTimeElapsed: _showBanner,
      );
}
