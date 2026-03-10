import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/sanctuary/providers/sanctuary_provider.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_health_indicator.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Stub auth notifier — returns fixed state without async work (no pending timers)
// ---------------------------------------------------------------------------

final _anonUser = UserProfile(
  id: 'anon-test',
  email: '',
  createdAt: DateTime(2024),
);

class _StubAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState.authenticated(_anonUser);
}

// ---------------------------------------------------------------------------
// Stub upgrade-prompt notifier — returns inert state, never starts a Timer
// ---------------------------------------------------------------------------

class _StubUpgradePromptNotifier extends UpgradePromptNotifier {
  @override
  UpgradePromptState build() => const UpgradePromptState(
        totalCollected: 0,
        supabaseInitialized: false,
      );
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

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
  FaunaDefinition(
    id: 'fauna_loxodonta_africana',
    displayName: 'African Elephant',
    scientificName: 'Loxodonta africana',
    taxonomicClass: 'Mammalia',
    continents: [Continent.africa],
    habitats: [Habitat.plains],
    rarity: IucnStatus.endangered,
  ),
];

Future<void> _pumpScreen(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      speciesServiceProvider.overrideWith(
        (_) => SpeciesService(_testSpecies),
      ),
      authProvider.overrideWith(_StubAuthNotifier.new),
      upgradePromptProvider.overrideWith(_StubUpgradePromptNotifier.new),
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
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SanctuaryScreen', () {
    testWidgets('renders without error', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SanctuaryScreen), findsOneWidget);
    });

    testWidgets('shows "Sanctuary" title in AppBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Sanctuary'), findsOneWidget);
    });

    testWidgets('shows SanctuaryHealthIndicator in Zoo tab', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SanctuaryHealthIndicator), findsOneWidget);
    });

    testWidgets('shows empty state in Zoo tab when nothing collected',
        (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(EmptyStateWidget), findsOneWidget);
    });

    testWidgets('shows 0% health indicator when nothing collected',
        (tester) async {
      await _pumpScreen(tester);
      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows species count', (tester) async {
      await _pumpScreen(tester);
      // Should show "0 / 2 species" (0 collected out of 2 test species)
      expect(find.textContaining('species'), findsWidgets);
    });

    // -----------------------------------------------------------------------
    // Tab bar tests
    // -----------------------------------------------------------------------

    testWidgets('renders TabBar with all 5 sanctuary tabs', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(TabBar), findsOneWidget);

      for (final tab in SanctuaryTab.values) {
        expect(
          find.text('${tab.icon} ${tab.displayName}'),
          findsOneWidget,
          reason: '${tab.displayName} tab label should be visible',
        );
      }
    });

    testWidgets('Zoo tab is selected by default', (tester) async {
      await _pumpScreen(tester);
      // Zoo tab content (health indicator) is visible on load
      expect(find.byType(SanctuaryHealthIndicator), findsOneWidget);
    });

    testWidgets('tapping Feeding tab shows coming-soon stub', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('🍎 Feeding'));
      await tester.pumpAndSettle();
      expect(find.text('Feeding coming soon'), findsOneWidget);
    });

    testWidgets('tapping Breeding tab shows coming-soon stub', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('🧬 Breeding'));
      await tester.pumpAndSettle();
      expect(find.text('Breeding coming soon'), findsOneWidget);
    });

    testWidgets('tapping Museum tab shows coming-soon stub', (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('🏛️ Museum'));
      await tester.pumpAndSettle();
      expect(find.text('Museum coming soon'), findsOneWidget);
    });

    testWidgets('tapping Achievements tab shows achievement list',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.text('🏆 Achievements'));
      await tester.pumpAndSettle();
      // Achievement list shows "X / Y Unlocked" header
      expect(find.textContaining('Unlocked'), findsOneWidget);
    });

    testWidgets('does not show trophy icon button in AppBar', (tester) async {
      await _pumpScreen(tester);
      // Trophy icon was removed — achievements are now a tab
      expect(find.byIcon(Icons.emoji_events), findsNothing);
    });
  });
}
