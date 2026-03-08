/// Integration test: upgrade flow wired across SanctuaryScreen, PackScreen,
/// and SettingsScreen.
///
/// Tests the full end-to-end upgrade prompt lifecycle:
/// 1. UpgradePromptProvider state transitions (0→5 species, markShown, etc.)
/// 2. Supabase gate (prompt suppressed when SDK not initialized)
/// 3. SaveProgressBanner visibility in SanctuaryScreen and PackScreen
///
/// All mocks are hand-written — no mockito / mocktail.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:earth_nova/core/config/supabase_bootstrap.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/core/models/item_instance.dart';
import 'package:earth_nova/core/state/inventory_provider.dart';
import 'package:earth_nova/core/state/supabase_bootstrap_provider.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
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

/// Mock auth notifier that returns a fixed state, bypassing async init.
class _MockAuthNotifier extends AuthNotifier {
  _MockAuthNotifier({required bool isAnonymous}) : _isAnonymous = isAnonymous;

  final bool _isAnonymous;

  @override
  AuthState build() {
    final user = UserProfile(
      id: 'mock-user',
      email: 'mock@example.com',
      createdAt: DateTime(2024),
      isAnonymous: _isAnonymous,
    );
    return AuthState.authenticated(user);
  }
}

/// SupabaseBootstrap subclass with controllable initialized flag.
class _FakeBootstrap extends SupabaseBootstrap {
  _FakeBootstrap({required bool initialized}) : _testInitialized = initialized;

  final bool _testInitialized;

  @override
  bool get initialized => _testInitialized;
}

/// Stub notifier that watches real providers but skips the session timer.
///
/// The real [UpgradePromptNotifier] starts a 120-second [Timer] on build,
/// which causes "Pending timers" failures in widget tests. This stub
/// preserves reactive integration (watches inventory/auth/supabase) while
/// bypassing the timer by setting [sessionTimeElapsed] = true immediately.
class _IntegrationUpgradePromptNotifier extends UpgradePromptNotifier {
  bool _hasBeenShown = false;

  @override
  UpgradePromptState build() {
    final totalCollected = ref.watch(inventoryProvider).totalItems;
    final isAnonymous = ref.watch(authProvider).isAnonymous;
    final supabaseInitialized = ref.read(supabaseBootstrapProvider).initialized;

    return UpgradePromptState(
      totalCollected: totalCollected,
      isAnonymous: isAnonymous,
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
  required bool isAnonymous,
  required bool supabaseInitialized,
}) async {
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
  required bool isAnonymous,
  required bool supabaseInitialized,
}) async {
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
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isFalse);
      expect(state.totalCollected, 4);
    });

    test('collection reaches 5: shouldShow becomes true, showBanner true', () {
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

    test('markShown() sets shouldShow=false, showBanner stays true', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).shouldShow, isTrue);

      container.read(upgradePromptProvider.notifier).markShown();

      final state = container.read(upgradePromptProvider);
      expect(state.shouldShow, isFalse);
      expect(state.showBanner, isTrue);
      expect(state.hasBeenShown, isTrue);
    });

    test('after upgrade (isAnonymous→false) showBanner becomes false', () {
      final container = _makeContainer(
        collectionCount: 10,
        isAnonymous: false,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      final state = container.read(upgradePromptProvider);
      expect(state.showBanner, isFalse);
      expect(state.shouldShow, isFalse);
    });

    test('hasBeenShown preserved across reactive rebuilds', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
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
      expect(state.showBanner, isTrue);
    });
  });

  // ── Supabase gate ─────────────────────────────────────────────────────────

  group('Supabase gate', () {
    test(
        'shouldShow is false when supabaseInitialized=false regardless of count',
        () {
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

    test('showBanner is false when supabaseInitialized=false', () {
      final container = _makeContainer(
        collectionCount: 20,
        isAnonymous: true,
        supabaseInitialized: false,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).showBanner, isFalse);
    });

    test('prompt appears when supabaseInitialized=true and count>=5', () {
      final container = _makeContainer(
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );
      addTearDown(container.dispose);

      expect(container.read(upgradePromptProvider).shouldShow, isTrue);
    });
  });

  // ── SanctuaryScreen widget tests ─────────────────────────────────────────

  group('SanctuaryScreen includes SaveProgressBanner', () {
    // Note: SanctuaryScreen uses a CustomScrollView with lazy sliver rendering.
    // SaveProgressBanner (as SizedBox.shrink) may not appear in the rendered
    // viewport when showBanner=false and the header card fills the screen.
    // Functional visibility tests below are the authoritative coverage.

    testWidgets('banner is visible when threshold met and user is anonymous',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsOneWidget);
    });

    testWidgets('banner is hidden when collection is below threshold',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 2,
        isAnonymous: true,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when user has upgraded (not anonymous)',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 10,
        isAnonymous: false,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when supabase not initialized',
        (tester) async {
      await _pumpSanctuaryScreen(
        tester,
        collectionCount: 10,
        isAnonymous: true,
        supabaseInitialized: false,
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
        isAnonymous: true,
        supabaseInitialized: true,
      );

      expect(find.byType(SaveProgressBanner), findsOneWidget);
    });

    testWidgets('banner is visible when threshold met and user is anonymous',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 5,
        isAnonymous: true,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsOneWidget);
    });

    testWidgets('banner is hidden when collection is below threshold',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 3,
        isAnonymous: true,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when user has upgraded (not anonymous)',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 10,
        isAnonymous: false,
        supabaseInitialized: true,
      );

      expect(find.text('Save your progress'), findsNothing);
    });

    testWidgets('banner is hidden when supabase not initialized',
        (tester) async {
      await _pumpPackScreen(
        tester,
        collectionCount: 10,
        isAnonymous: true,
        supabaseInitialized: false,
      );

      expect(find.text('Save your progress'), findsNothing);
    });
  });

  // ── SaveProgressBanner standalone widget tests ────────────────────────────

  group('SaveProgressBanner widget', () {
    testWidgets('renders "Save your progress" when showBanner=true',
        (tester) async {
      await tester.pumpWidget(_wrapBanner(showBanner: true));
      expect(find.text('Save your progress'), findsOneWidget);
    });

    testWidgets('renders nothing when showBanner=false', (tester) async {
      await tester.pumpWidget(_wrapBanner(showBanner: false));
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
        isAnonymous: _showBanner,
        supabaseInitialized: _showBanner,
        sessionTimeElapsed: _showBanner,
      );
}
