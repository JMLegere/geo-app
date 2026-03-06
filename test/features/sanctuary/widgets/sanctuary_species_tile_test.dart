import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/features/sanctuary/widgets/sanctuary_species_tile.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _forestFox = FaunaDefinition(
  id: 'fauna_vulpes_vulpes',
  displayName: 'Red Fox',
  scientificName: 'Vulpes vulpes',
  taxonomicClass: 'Mammalia',
  continents: [Continent.europe],
  habitats: [Habitat.forest],
  rarity: IucnStatus.leastConcern,
);

final _jaguar = FaunaDefinition(
  id: 'fauna_panthera_onca',
  displayName: 'Jaguar',
  scientificName: 'Panthera onca',
  taxonomicClass: 'Mammalia',
  continents: [Continent.southAmerica],
  habitats: [Habitat.forest],
  rarity: IucnStatus.nearThreatened,
);

final _snowLeopard = FaunaDefinition(
  id: 'fauna_panthera_uncia',
  displayName: 'Snow Leopard',
  scientificName: 'Panthera uncia',
  taxonomicClass: 'Mammalia',
  continents: [Continent.asia],
  habitats: [Habitat.mountain],
  rarity: IucnStatus.vulnerable,
);

final _elephant = FaunaDefinition(
  id: 'fauna_loxodonta_africana',
  displayName: 'African Elephant',
  scientificName: 'Loxodonta africana',
  taxonomicClass: 'Mammalia',
  continents: [Continent.africa],
  habitats: [Habitat.plains],
  rarity: IucnStatus.endangered,
);

Future<void> _pumpTile(WidgetTester tester, FaunaDefinition species) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SanctuarySpeciesTile(species: species),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SanctuarySpeciesTile', () {
    testWidgets('shows species common name', (tester) async {
      await _pumpTile(tester, _forestFox);
      expect(find.text('Red Fox'), findsOneWidget);
    });

    testWidgets('shows species scientific name', (tester) async {
      await _pumpTile(tester, _forestFox);
      expect(find.text('Vulpes vulpes'), findsOneWidget);
    });

    testWidgets('shows LC rarity badge for least concern species',
        (tester) async {
      await _pumpTile(tester, _forestFox);
      expect(find.text('LC'), findsOneWidget);
    });

    testWidgets('shows NT rarity badge for near-threatened species',
        (tester) async {
      await _pumpTile(tester, _jaguar);
      expect(find.text('NT'), findsOneWidget);
    });

    testWidgets('shows VU rarity badge for vulnerable species', (tester) async {
      await _pumpTile(tester, _snowLeopard);
      expect(find.text('VU'), findsOneWidget);
    });

    testWidgets('shows EN rarity badge for endangered species', (tester) async {
      await _pumpTile(tester, _elephant);
      expect(find.text('EN'), findsOneWidget);
    });

    testWidgets('shows common name of jaguar', (tester) async {
      await _pumpTile(tester, _jaguar);
      expect(find.text('Jaguar'), findsOneWidget);
    });

    testWidgets('shows scientific name of jaguar', (tester) async {
      await _pumpTile(tester, _jaguar);
      expect(find.text('Panthera onca'), findsOneWidget);
    });
  });
}
