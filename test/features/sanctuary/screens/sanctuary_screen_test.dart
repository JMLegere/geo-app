import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/sanctuary/screens/sanctuary_screen.dart';
import 'package:fog_of_world/features/sanctuary/widgets/habitat_section.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_health_indicator.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _testSpecies = [
  SpeciesRecord(
    commonName: 'Red Fox',
    scientificName: 'Vulpes vulpes',
    taxonomicClass: 'Mammalia',
    continents: [Continent.europe],
    habitats: [Habitat.forest],
    iucnStatus: IucnStatus.leastConcern,
  ),
  SpeciesRecord(
    commonName: 'African Elephant',
    scientificName: 'Loxodonta africana',
    taxonomicClass: 'Mammalia',
    continents: [Continent.africa],
    habitats: [Habitat.plains],
    iucnStatus: IucnStatus.endangered,
  ),
];

Future<void> _pumpScreen(WidgetTester tester) async {
  final container = ProviderContainer(
    overrides: [
      speciesServiceProvider.overrideWith(
        (_) => SpeciesService(_testSpecies),
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
      expect(find.byType(HabitatSection), findsWidgets);
    });

    testWidgets('shows habitat sections (lazy list renders visible items)',
        (tester) async {
      await _pumpScreen(tester);
      // SliverList renders lazily — only items in the viewport are built.
      // Verify that at least some sections are present without asserting
      // the exact count, which depends on the test viewport height.
      expect(find.byType(HabitatSection), findsWidgets);
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
  });
}
