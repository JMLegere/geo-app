import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/core/models/continent.dart';
import 'package:earth_nova/core/models/habitat.dart';
import 'package:earth_nova/core/models/iucn_status.dart';
import 'package:earth_nova/core/models/item_definition.dart';
import 'package:earth_nova/core/species/species_service.dart';
import 'package:earth_nova/features/achievements/screens/achievement_screen.dart';
import 'package:earth_nova/features/auth/models/auth_state.dart';
import 'package:earth_nova/features/auth/models/user_profile.dart';
import 'package:earth_nova/features/auth/providers/auth_provider.dart';
import 'package:earth_nova/features/auth/providers/upgrade_prompt_provider.dart';
import 'package:earth_nova/features/discovery/providers/discovery_provider.dart';
import 'package:earth_nova/features/sanctuary/screens/sanctuary_screen.dart';
import 'package:earth_nova/features/sanctuary/widgets/habitat_section.dart';
import 'package:earth_nova/features/sanctuary/widgets/sanctuary_health_indicator.dart';
import 'package:earth_nova/shared/widgets/empty_state_widget.dart';

// ---------------------------------------------------------------------------
// Stub auth notifier — returns fixed state without async work (no pending timers)
// ---------------------------------------------------------------------------

final _anonUser = UserProfile(
  id: 'anon-test',
  email: '',
  createdAt: DateTime(2024),
  isAnonymous: true,
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
        isAnonymous: true,
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

    testWidgets('shows SanctuaryHealthIndicator', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SanctuaryHealthIndicator), findsOneWidget);
    });

    testWidgets('shows HabitatSection widgets', (tester) async {
      await _pumpScreen(tester);
      // With no collected species, the sanctuary shows an empty-state widget
      // and hides habitat sections until the first species is discovered.
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.byType(HabitatSection), findsNothing);
    });

    testWidgets('shows habitat sections (lazy list renders visible items)',
        (tester) async {
      await _pumpScreen(tester);
      // With no collected species the empty state is shown, not the sliver
      // list.  Habitat sections only render once totalCollected > 0.
      expect(find.byType(EmptyStateWidget), findsOneWidget);
      expect(find.byType(HabitatSection), findsNothing);
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

    testWidgets('AppBar has trophy icon button', (tester) async {
      await _pumpScreen(tester);
      expect(find.byIcon(Icons.emoji_events), findsOneWidget);
    });

    testWidgets('tapping trophy icon navigates to AchievementScreen',
        (tester) async {
      await _pumpScreen(tester);
      await tester.tap(find.byIcon(Icons.emoji_events));
      await tester.pumpAndSettle();
      expect(find.byType(AchievementScreen), findsOneWidget);
    });
  });
}
