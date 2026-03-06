import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fog_of_world/core/models/continent.dart';
import 'package:fog_of_world/core/models/habitat.dart';
import 'package:fog_of_world/core/models/iucn_status.dart';
import 'package:fog_of_world/core/models/item_definition.dart';
import 'package:fog_of_world/features/pack/widgets/species_card.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

final _redFox = FaunaDefinition(
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
  habitats: [Habitat.forest, Habitat.swamp],
  rarity: IucnStatus.nearThreatened,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required FaunaDefinition species,
  required bool isCollected,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 160,
          height: 220,
          child: SpeciesCard(
            species: species,
            isCollected: isCollected,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SpeciesCard — collected state', () {
    testWidgets('shows species common name', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      expect(find.text('Red Fox'), findsOneWidget);
    });

    testWidgets('shows LC rarity badge', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      expect(find.text('LC'), findsOneWidget);
    });

    testWidgets('shows NT rarity badge for near-threatened species',
        (tester) async {
      await _pumpCard(tester, species: _jaguar, isCollected: true);
      expect(find.text('NT'), findsOneWidget);
    });

    testWidgets('shows collected checkmark indicator', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      // The collected label text is always present
      expect(find.text('✓ Collected'), findsOneWidget);
    });

    testWidgets('shows check_circle icon', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets('does NOT show "???" placeholder text', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      expect(find.text('???'), findsNothing);
    });

    testWidgets('does NOT show "Not discovered" label', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: true);
      expect(find.text('Not discovered'), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await _pumpCard(
        tester,
        species: _redFox,
        isCollected: true,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(SpeciesCard));
      expect(tapped, isTrue);
    });
  });

  group('SpeciesCard — uncollected state', () {
    testWidgets('shows "???" placeholder instead of real name', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: false);
      expect(find.text('???'), findsOneWidget);
    });

    testWidgets('does NOT show real species name', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: false);
      expect(find.text('Red Fox'), findsNothing);
    });

    testWidgets('does NOT show rarity badge', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: false);
      expect(find.text('LC'), findsNothing);
    });

    testWidgets('shows "Not discovered" label', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: false);
      expect(find.text('Not discovered'), findsOneWidget);
    });

    testWidgets('does NOT show collected checkmark', (tester) async {
      await _pumpCard(tester, species: _redFox, isCollected: false);
      expect(find.text('✓ Collected'), findsNothing);
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await _pumpCard(
        tester,
        species: _redFox,
        isCollected: false,
        onTap: () => tapped = true,
      );

      await tester.tap(find.byType(SpeciesCard));
      expect(tapped, isTrue);
    });
  });
}
