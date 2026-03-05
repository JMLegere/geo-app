import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/species.dart';
import 'package:fog_of_world/features/sanctuary/widgets/habitat_section.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_species_tile.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _fox = SpeciesRecord(
  commonName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  taxonomicClass: 'Mammalia',
  continents: [Continent.europe],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.leastConcern,
);

final _bear = SpeciesRecord(
  commonName: 'Grizzly Bear',
  scientificName: 'Ursus arctos horribilis',
  taxonomicClass: 'Mammalia',
  continents: [Continent.northAmerica],
  habitats: [Habitat.forest],
  iucnStatus: IucnStatus.leastConcern,
);

Future<void> _pumpSection(
  WidgetTester tester, {
  required Habitat habitat,
  required List<SpeciesRecord> species,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HabitatSection(habitat: habitat, species: species),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('HabitatSection', () {
    testWidgets('renders habitat name', (tester) async {
      await _pumpSection(
          tester, habitat: Habitat.forest, species: [_fox]);
      expect(find.text('Forest'), findsOneWidget);
    });

    testWidgets('renders plains habitat name', (tester) async {
      await _pumpSection(tester, habitat: Habitat.plains, species: []);
      expect(find.text('Plains'), findsOneWidget);
    });

    testWidgets('renders correct species count when species present',
        (tester) async {
      await _pumpSection(
          tester, habitat: Habitat.forest, species: [_fox, _bear]);
      expect(find.text('2 species'), findsOneWidget);
    });

    testWidgets('renders "0 species" count when empty', (tester) async {
      await _pumpSection(tester, habitat: Habitat.forest, species: []);
      expect(find.text('0 species'), findsOneWidget);
    });

    testWidgets('renders SanctuarySpeciesTile for each species', (tester) async {
      await _pumpSection(
          tester, habitat: Habitat.forest, species: [_fox, _bear]);
      expect(find.byType(SanctuarySpeciesTile), findsNWidgets(2));
    });

    testWidgets('shows explore message when habitat is empty', (tester) async {
      await _pumpSection(tester, habitat: Habitat.forest, species: []);
      expect(
        find.text('Explore forest areas to discover species'),
        findsOneWidget,
      );
    });

    testWidgets('shows plains explore message for plains habitat',
        (tester) async {
      await _pumpSection(tester, habitat: Habitat.plains, species: []);
      expect(
        find.text('Explore plains areas to discover species'),
        findsOneWidget,
      );
    });

    testWidgets('does NOT show explore message when species present',
        (tester) async {
      await _pumpSection(
          tester, habitat: Habitat.forest, species: [_fox]);
      expect(
        find.textContaining('Explore'),
        findsNothing,
      );
    });

    testWidgets('renders GridView when species are present', (tester) async {
      await _pumpSection(
          tester, habitat: Habitat.forest, species: [_fox, _bear]);
      expect(find.byType(GridView), findsOneWidget);
    });

    testWidgets('does NOT render GridView when species list is empty',
        (tester) async {
      await _pumpSection(tester, habitat: Habitat.forest, species: []);
      expect(find.byType(GridView), findsNothing);
    });
  });
}
