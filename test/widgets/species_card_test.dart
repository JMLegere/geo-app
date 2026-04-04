import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:earth_nova/models/item.dart';
import 'package:earth_nova/widgets/species_card.dart';

void main() {
  group('SpeciesCard', () {
    testWidgets('displays species name and scientific name', (tester) async {
      final item = _item(
        name: 'Red Fox',
        scientificName: 'Vulpes vulpes',
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Red Fox'), findsOneWidget);
      expect(find.text('Vulpes vulpes'), findsOneWidget);
    });

    testWidgets('displays rarity badge when rarity is set', (tester) async {
      final item = _item(rarity: 'endangered');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.textContaining('EN'), findsOneWidget);
      expect(find.textContaining('Endangered'), findsOneWidget);
    });

    testWidgets('displays category chip', (tester) async {
      final item = _item(category: ItemCategory.flora);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Flora'), findsOneWidget);
    });

    testWidgets('displays habitat chips when present', (tester) async {
      final item = _item(habitats: ['Forest', 'Mountain']);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('HABITAT'), findsOneWidget);
      expect(find.text('Forest'), findsOneWidget);
      expect(find.text('Mountain'), findsOneWidget);
    });

    testWidgets('displays region chips when present', (tester) async {
      final item = _item(continents: ['Africa', 'Asia']);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('REGION'), findsOneWidget);
      expect(find.text('Africa'), findsOneWidget);
      expect(find.text('Asia'), findsOneWidget);
    });

    testWidgets('displays acquired date', (tester) async {
      final item = _item();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('DISCOVERED'), findsOneWidget);
      expect(find.text('Jan 15, 2026'), findsOneWidget);
    });

    testWidgets('displays taxonomic group for fauna', (tester) async {
      final item = _item(taxonomicClass: 'MAMMALIA');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Mammals'), findsOneWidget);
    });

    testWidgets('hides habitat/region when empty', (tester) async {
      final item = _item();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('HABITAT'), findsNothing);
      expect(find.text('REGION'), findsNothing);
    });

    testWidgets('showSpeciesCard opens bottom sheet', (tester) async {
      final item = _item(name: 'Test Species');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showSpeciesCard(context, item),
              child: const Text('Open'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Species'), findsOneWidget);
    });

    testWidgets('displays cell ID when available', (tester) async {
      final item = _item(cellId: 'v_45_67');

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SpeciesCard(item: item)),
      ));

      expect(find.text('Cell v_45_67'), findsOneWidget);
    });
  });
}

Item _item({
  String name = 'Test Animal',
  String? scientificName,
  String? rarity,
  ItemCategory category = ItemCategory.fauna,
  String? taxonomicClass,
  List<String> habitats = const [],
  List<String> continents = const [],
  String? cellId,
}) =>
    Item(
      id: 'test-1',
      definitionId: 'def-1',
      displayName: name,
      scientificName: scientificName,
      category: category,
      rarity: rarity,
      acquiredAt: DateTime(2026, 1, 15),
      acquiredInCellId: cellId,
      status: ItemStatus.active,
      taxonomicClass: taxonomicClass,
      habitats: habitats,
      continents: continents,
    );
