import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/core/species/species_service.dart';
import 'package:fog_of_world/features/discovery/providers/discovery_provider.dart';
import 'package:fog_of_world/features/pack/screens/pack_screen.dart';
import 'package:fog_of_world/features/pack/widgets/pack_filter_bar.dart';
import 'package:fog_of_world/features/pack/widgets/pack_progress_bar.dart';
import 'package:fog_of_world/features/pack/widgets/species_card.dart';

// ---------------------------------------------------------------------------
// Test fixtures
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
    iucnStatus: IucnStatus.vulnerable,
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
      child: const MaterialApp(
        home: PackScreen(),
      ),
    ),
  );

  // Allow any async build work to settle
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PackScreen', () {
    testWidgets('renders without error', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(PackScreen), findsOneWidget);
    });

    testWidgets('shows "Pack" title in AppBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('Pack'), findsOneWidget);
    });

    testWidgets('shows PackProgressBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(PackProgressBar), findsOneWidget);
    });

    testWidgets('shows PackFilterBar', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(PackFilterBar), findsOneWidget);
    });

    testWidgets('shows grid of SpeciesCard widgets', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SpeciesCard), findsWidgets);
    });

    testWidgets('shows correct number of species cards', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(SpeciesCard), findsNWidgets(_testSpecies.length));
    });

    testWidgets('shows species names in uncollected state', (tester) async {
      await _pumpScreen(tester);
      // All species are uncollected → names show as "???"
      expect(find.text('???'), findsNWidgets(_testSpecies.length));
    });

    testWidgets('shows progress bar with 0 / 2 collected', (tester) async {
      await _pumpScreen(tester);
      expect(find.text('0 / 2 collected'), findsOneWidget);
    });

    testWidgets('renders GridView', (tester) async {
      await _pumpScreen(tester);
      expect(find.byType(GridView), findsOneWidget);
    });
  });
}
